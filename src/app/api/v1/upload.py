"""
Image upload endpoint.

Accepts a multipart/form-data POST with a single ``file`` field or multiple
``files`` fields.  When storage credentials are configured via environment
variables the file is uploaded to the configured S3-compatible bucket and the
public URL is returned.  When credentials are absent (local / test environment)
the endpoint returns a stub URL so that the rest of the API still works.

Primary environment variables (ORT Media storage)
--------------------------------------------------
ORT_MEDIAA_API      S3-compatible endpoint URL (e.g. https://s3.example.com)
ORT_MEDIAA_KEY      Access key / API token for the storage service
ORT_MEDIAA_NAME     Bucket / container name
ORT_MEDIAA_SECRET   Secret key (optional; defaults to ORT_MEDIAA_KEY)
S3_PUBLIC_BASE_URL  Public base URL to prefix uploaded keys with

Railway / Render bucket environment variables (checked second)
--------------------------------------------------------------
BUCKET_ACCESS_KEY_ID
BUCKET_SECRET_ACCESS_KEY
BUCKET_NAME
BUCKET_ENDPOINT_URL
BUCKET_REGION       (default: us-east-1)

Legacy fallback environment variables
--------------------------------------
AWS_ACCESS_KEY_ID
AWS_SECRET_ACCESS_KEY
AWS_REGION          (default: us-east-1)
S3_BUCKET_NAME
S3_ENDPOINT_URL
S3_PUBLIC_BASE_URL

Public URL resolution
---------------------
By default ALL uploaded objects are served through the API's own proxy:
  GET /api/v1/upload/proxy/<object-key>

This guarantees images are always reachable from the frontend regardless of
whether the storage provider supports public-read ACLs or has CORS configured.
Railway buckets, for example, do not support per-object ACLs so uploaded
objects are private; direct bucket URLs would return 403 for Flutter Web.

To serve images directly from the bucket (e.g. from a CDN or an AWS S3 bucket
with a public-read bucket policy) set S3_PUBLIC_BASE_URL to the bucket's
public-facing base URL.  When that variable is set, uploaded objects return
a direct URL:  ``<S3_PUBLIC_BASE_URL>/<object-key>``
"""


import io
import asyncio
import logging
import os
import uuid
import re
from typing import List, Optional
from urllib.parse import urlparse as _urlparse

from fastapi import APIRouter, Depends, HTTPException, Query, UploadFile, File, status
from fastapi.responses import Response
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
from jose import jwt, JWTError
from sqlalchemy.exc import SQLAlchemyError
from sqlalchemy.orm import Session

from app.database.database import get_db

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/upload", tags=["upload"])

_SECRET_KEY = os.getenv("SECRET_KEY", "change-me-in-production")
_ALGORITHM = "HS256"
_bearer = HTTPBearer(auto_error=False)


def _get_optional_user_id(
    credentials: HTTPAuthorizationCredentials = Depends(_bearer),
) -> Optional[int]:
    """Decode JWT and return the user's integer ID, or None if unauthenticated."""
    if credentials is None:
        return None
    try:
        payload = jwt.decode(credentials.credentials, _SECRET_KEY, algorithms=[_ALGORITHM])
        sub = payload.get("sub")
        if sub is None:
            return None
        return int(sub)
    except (JWTError, ValueError):
        return None


def _get_required_user(
    credentials: HTTPAuthorizationCredentials = Depends(_bearer),
    db: Session = Depends(get_db),
):
    """Decode JWT and return the User record; raise 401 if missing or invalid."""
    from app.models.models import User

    if credentials is None:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Authentication required",
        )
    try:
        payload = jwt.decode(credentials.credentials, _SECRET_KEY, algorithms=[_ALGORITHM])
        sub = payload.get("sub")
        if sub is None:
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED, detail="Invalid token"
            )
        user_id = int(sub)
    except (JWTError, ValueError):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED, detail="Invalid token"
        )
    user = db.query(User).filter(User.id == user_id).first()
    if not user:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED, detail="User not found"
        )
    return user


_ALLOWED_CONTENT_TYPES = {
    "image/jpeg",
    "image/jpg",
    "image/png",
    "image/webp",
    "image/gif",
}
_MAX_SIZE_BYTES = 10 * 1024 * 1024  # 10 MB


def _get_s3_config():
    """Return (key_id, secret, endpoint_url, bucket, public_base) from env vars.

    Checks ORT_MEDIAA_* vars first, then Render BUCKET_* vars, then falls back
    to legacy AWS_* / S3_* vars.  Returns None if essential credentials are not
    available.
    """
    # ── Primary: ORT_MEDIAA_* ────────────────────────────────────────────────
    ort_key = os.getenv("ORT_MEDIAA_KEY")
    ort_name = os.getenv("ORT_MEDIAA_NAME")
    ort_api = os.getenv("ORT_MEDIAA_API")

    if ort_key and ort_name:
        secret = os.getenv("ORT_MEDIAA_SECRET", ort_key)
        public_base = os.getenv("S3_PUBLIC_BASE_URL", "").rstrip("/")
        if not public_base and ort_api:
            public_base = f"{ort_api.rstrip('/')}/{ort_name}"
        return {
            "key_id": ort_key,
            "secret": secret,
            "endpoint_url": ort_api,
            "bucket": ort_name,
            "public_base": public_base,
            "region": os.getenv("AWS_REGION", "us-east-1"),
        }

    # ── Railway / Render bucket vars: BUCKET_* ──────────────────────────────
    bucket_key_id = os.getenv("BUCKET_ACCESS_KEY_ID")
    bucket_secret = os.getenv("BUCKET_SECRET_ACCESS_KEY")
    bucket_name = os.getenv("BUCKET_NAME")

    if bucket_key_id and bucket_secret and bucket_name:
        endpoint_url = os.getenv("BUCKET_ENDPOINT_URL")
        region = os.getenv("BUCKET_REGION", "us-east-1")
        public_base = os.getenv("S3_PUBLIC_BASE_URL", "").rstrip("/")
        if not public_base and endpoint_url:
            # Railway buckets expose objects at a virtual-hosted-style URL:
            #   https://<bucket-name>.<endpoint-host>
            # The BUCKET_ENDPOINT_URL is the S3-API endpoint used for uploads
            # (e.g. https://bucket.us-east-1.railway.app) which is NOT the
            # same as the public download URL.  We construct the public URL by
            # prepending the bucket name as a subdomain of the endpoint host.
            _parsed = _urlparse(endpoint_url)
            _host = _parsed.netloc or _parsed.path  # handle bare hostnames
            public_base = f"{_parsed.scheme}://{bucket_name}.{_host}"
        return {
            "key_id": bucket_key_id,
            "secret": bucket_secret,
            "endpoint_url": endpoint_url,
            "bucket": bucket_name,
            "public_base": public_base,
            "region": region,
        }


    # ── Legacy: AWS_* / S3_* ─────────────────────────────────────────────────
    key_id = os.getenv("AWS_ACCESS_KEY_ID")
    secret = os.getenv("AWS_SECRET_ACCESS_KEY")
    bucket = os.getenv("S3_BUCKET_NAME")

    if key_id and secret and bucket:
        endpoint_url = os.getenv("S3_ENDPOINT_URL")
        public_base = os.getenv("S3_PUBLIC_BASE_URL", "").rstrip("/")
        if not public_base:
            if endpoint_url:
                # Non-AWS provider (e.g. Railway bucket) – derive a
                # virtual-hosted-style public URL from the endpoint, the same
                # way the BUCKET_* path does.
                _parsed = _urlparse(endpoint_url)
                _host = _parsed.netloc or _parsed.path
                public_base = f"{_parsed.scheme}://{bucket}.{_host}"
            else:
                region = os.getenv("AWS_REGION", "us-east-1")
                public_base = f"https://{bucket}.s3.{region}.amazonaws.com"
        return {
            "key_id": key_id,
            "secret": secret,
            "endpoint_url": endpoint_url,
            "bucket": bucket,
            "public_base": public_base,
            "region": os.getenv("AWS_REGION", "us-east-1"),
        }

    return None


def _get_s3_client():
    """Return a boto3 S3 client when credentials are configured, else None."""
    cfg = _get_s3_config()
    if not cfg:
        return None, None, None
    try:
        import boto3

        kwargs = {
            "aws_access_key_id": cfg["key_id"],
            "aws_secret_access_key": cfg["secret"],
            "region_name": cfg["region"],
        }
        if cfg["endpoint_url"]:
            kwargs["endpoint_url"] = cfg["endpoint_url"]
        return boto3.client("s3", **kwargs), cfg["bucket"], cfg["public_base"]
    except ImportError:
        logger.warning("boto3 not installed – image upload will use stub mode")
        return None, None, None


async def _process_upload(file: UploadFile, db: Session, uploader_user_id: Optional[int] = None) -> dict:
    """Validate, upload and return ``{"url": ...}`` for a single file."""
    # Content-type validation
    if file.content_type not in _ALLOWED_CONTENT_TYPES:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Unsupported file type '{file.content_type}'. "
                   f"Allowed: {', '.join(sorted(_ALLOWED_CONTENT_TYPES))}",
        )

    contents = await file.read()

    if len(contents) > _MAX_SIZE_BYTES:
        raise HTTPException(
            status_code=status.HTTP_413_REQUEST_ENTITY_TOO_LARGE,
            detail=f"File too large. Maximum size is {_MAX_SIZE_BYTES // 1024 // 1024} MB.",
        )

    ext = (file.filename or "image.jpg").rsplit(".", 1)[-1].lower()
    if ext not in {"jpg", "jpeg", "png", "webp", "gif"}:
        ext = "jpg"

    img_uuid = uuid.uuid4()
    object_key = f"listings/{img_uuid}.{ext}"

    s3, bucket, public_base = _get_s3_client()

    if s3 and bucket:
        try:
            try:
                s3.upload_fileobj(
                    io.BytesIO(contents),
                    bucket,
                    object_key,
                    ExtraArgs={"ContentType": file.content_type, "ACL": "public-read"},
                )
            except Exception as acl_exc:
                # Some S3-compatible providers (e.g. Railway buckets) do not
                # support ACLs and return an error when the ACL extra arg is
                # included.  Fall back to uploading without the ACL header.
                # We catch broadly here because the exact error class varies
                # by provider (ClientError for AWS/boto3-compatible, or a
                # plain Exception for others).
                logger.warning(
                    "Upload with ACL=public-read failed (%s); retrying without ACL.", acl_exc
                )
                s3.upload_fileobj(
                    io.BytesIO(contents),
                    bucket,
                    object_key,
                    ExtraArgs={"ContentType": file.content_type},
                )
            _explicit_public_base = os.getenv("S3_PUBLIC_BASE_URL", "").rstrip("/")
            if _explicit_public_base:
                # Caller has explicitly declared a public CDN / bucket URL;
                # trust it and use direct object URLs for best performance.
                url = f"{_explicit_public_base}/{object_key}"
            else:
                # Default: route all image requests through the API proxy.
                # This guarantees accessibility regardless of whether the
                # storage provider supports public-read ACLs.  Railway buckets,
                # for example, do not support per-object ACLs, so derived
                # virtual-hosted-style URLs return 403 for unauthenticated
                # requests.  The proxy uses the configured S3 credentials to
                # download the object and serve it with proper CORS headers.
                # To opt out and use direct bucket URLs, set S3_PUBLIC_BASE_URL
                # to the public-facing base URL of the bucket.
                app_base = os.getenv("APP_BASE_URL", "https://ort.up.railway.app").rstrip("/")
                url = f"{app_base}/api/v1/upload/proxy/{object_key}"
            logger.info("Uploaded image to S3 key: %s → %s", object_key, url)
            _record_upload(db, key=object_key, user_id=uploader_user_id)
            return {"url": url}
        except Exception as exc:
            logger.error("S3 upload failed: %s", exc)
            raise HTTPException(
                status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
                detail="Image upload failed. Please try again.",
            ) from exc

    else:
        # No S3 configured – persist image data in the database so it survives
        # container restarts (e.g. Railway ephemeral filesystem).
        from app.models.models import ImageBlob
        img_id = str(img_uuid)
        content_type = file.content_type or "image/jpeg"
        try:
            blob = ImageBlob(id=img_id, data=contents, content_type=content_type)
            db.add(blob)
            db.commit()
        except SQLAlchemyError as exc:
            db.rollback()
            logger.error("Failed to save image to database: %s", exc)
            raise HTTPException(
                status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
                detail="Image upload failed. Please try again.",
            ) from exc
        logger.warning(
            "S3 not configured – saved image to database with id %s", img_id
        )
        _record_upload(db, key=img_id, user_id=uploader_user_id)
        base_url = os.getenv("APP_BASE_URL", "https://ort.up.railway.app")
        return {"url": f"{base_url}/api/v1/upload/image/{img_id}"}


def _record_upload(db: Session, key: str, user_id: Optional[int]) -> None:
    """Persist an UploadRecord so we can verify ownership on deletion."""
    from app.models.models import UploadRecord
    try:
        record = UploadRecord(key=key, uploaded_by_user_id=user_id)
        db.add(record)
        db.commit()
    except SQLAlchemyError as exc:
        db.rollback()
        # Non-fatal – ownership tracking failure should not abort the upload.
        logger.warning("Failed to record upload ownership for key %s: %s", key, exc)


@router.post("/image", status_code=status.HTTP_200_OK)
async def upload_image(
    file: UploadFile = File(...),
    db: Session = Depends(get_db),
    uploader_user_id: Optional[int] = Depends(_get_optional_user_id),
):
    """Upload a single image file and return its public URL."""
    return await _process_upload(file, db, uploader_user_id=uploader_user_id)


@router.post("/images", status_code=status.HTTP_200_OK)
async def upload_images(
    files: List[UploadFile] = File(...),
    db: Session = Depends(get_db),
    uploader_user_id: Optional[int] = Depends(_get_optional_user_id),
):
    """Upload multiple image files (up to 20) and return their public URLs."""
    if not files:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="No files provided.",
        )
    if len(files) > 20:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Maximum 20 files per request.",
        )
    results = await asyncio.gather(*[_process_upload(f, db, uploader_user_id) for f in files])
    return {"urls": [r["url"] for r in results]}


@router.get("/image/{image_id}")
async def serve_image(
    image_id: str,
    db: Session = Depends(get_db),
):
    """Serve an image stored in the database (stub / no-S3 mode).

    Returns the raw image bytes with the original content-type header so
    Flutter's ``Image.network()`` and browser ``<img>`` tags display it.
    """
    from app.models.models import ImageBlob
    blob = db.query(ImageBlob).filter(ImageBlob.id == image_id).first()
    if not blob:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Image not found.",
        )
    return Response(
        content=blob.data,
        media_type=blob.content_type,
        headers={"Cache-Control": "public, max-age=31536000, immutable"},
    )


@router.get("/proxy/{object_key:path}")
async def proxy_image(object_key: str):
    """Proxy an image from S3 storage and return it with proper CORS headers.

    This is the default URL scheme used for all S3-backed uploads unless
    ``S3_PUBLIC_BASE_URL`` is explicitly configured.  Using the API proxy
    instead of direct bucket URLs means:

    * Private objects (e.g. Railway buckets that do not support public-read
      ACLs) are always accessible – the proxy uses S3 credentials.
    * CORS is handled by the FastAPI CORS middleware, so Flutter Web never
      encounters browser-level CORS rejections from the bucket.
    * No bucket-side CORS configuration is required.
    """
    s3, bucket, _ = _get_s3_client()
    if not s3 or not bucket:
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail="Storage not configured.",
        )

    # Guard against path-traversal attempts.  S3 object keys consist only of
    # printable characters but we reject any key that contains ".." segments
    # (which could reference unintended objects in the bucket).
    if re.search(r"(^|/)\.\.(/|$)", object_key):
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Invalid object key.",
        )

    try:
        buf = io.BytesIO()
        # Run the blocking boto3 call in a thread-pool executor so it does not
        # stall the async event loop under concurrent requests.
        await asyncio.get_running_loop().run_in_executor(
            None, lambda: s3.download_fileobj(bucket, object_key, buf)
        )
        data = buf.getvalue()
    except Exception as exc:
        logger.error("Proxy fetch failed for key %s: %s", object_key, exc)
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Image not found.",
        ) from exc

    # Determine content-type from the key extension; default to JPEG.
    ext = object_key.rsplit(".", 1)[-1].lower() if "." in object_key else ""
    _mime_map = {
        "jpg": "image/jpeg",
        "jpeg": "image/jpeg",
        "png": "image/png",
        "webp": "image/webp",
        "gif": "image/gif",
    }
    media_type = _mime_map.get(ext, "image/jpeg")

    return Response(
        content=data,
        media_type=media_type,
        headers={"Cache-Control": "public, max-age=31536000, immutable"},
    )


@router.delete("/image", status_code=status.HTTP_200_OK)
async def delete_image(
    url: str = Query(..., description="Public URL of the image to delete"),
    db: Session = Depends(get_db),
    current_user=Depends(_get_required_user),
):
    """Delete an uploaded image by its public URL.

    Requires authentication.  Only the admin or the user who originally
    uploaded the image may delete it.

    Removes the object from S3 / Railway bucket when storage is configured.
    In stub mode, removes the record from the database.

    Handles three URL formats:
      1. ``{public_base}/{object_key}``  – direct bucket URL
      2. ``{app_base}/api/v1/upload/proxy/{object_key}``  – proxy URL
      3. ``{app_base}/api/v1/upload/image/{uuid}``  – database blob URL
    """
    import urllib.parse
    from app.models.models import UploadRecord

    s3, bucket, public_base = _get_s3_client()

    # ── Resolve the lookup key from the URL ──────────────────────────────────
    parsed = urllib.parse.urlparse(url)
    path = parsed.path

    _proxy_prefix = "/api/v1/upload/proxy/"
    _blob_prefix = "/api/v1/upload/image/"

    if path.startswith(_proxy_prefix):
        lookup_key = path[len(_proxy_prefix):].strip("/")
    elif path.startswith(_blob_prefix):
        lookup_key = path[len(_blob_prefix):].strip("/")
    elif public_base and url.startswith(public_base):
        lookup_key = url[len(public_base):].lstrip("/")
    else:
        lookup_key = None

    # ── Authorisation check ──────────────────────────────────────────────────
    if current_user.role != "admin":
        if lookup_key is None:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="You do not have permission to delete this image.",
            )
        record = db.query(UploadRecord).filter(UploadRecord.key == lookup_key).first()
        if record is None or record.uploaded_by_user_id != current_user.id:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="You do not have permission to delete this image.",
            )

    # ── Perform the deletion ─────────────────────────────────────────────────
    if s3 and bucket:
        if lookup_key is None:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="URL does not belong to the configured storage bucket.",
            )
        try:
            s3.delete_object(Bucket=bucket, Key=lookup_key)
            logger.info("Deleted S3 object: %s (by user %s)", lookup_key, current_user.id)
        except Exception as exc:
            logger.error("S3 delete failed: %s", exc)
            raise HTTPException(
                status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
                detail="Image deletion failed. Please try again.",
            ) from exc
    else:
        # Stub mode: delete from database by image ID.
        from app.models.models import ImageBlob
        if lookup_key is not None:
            blob = db.query(ImageBlob).filter(ImageBlob.id == lookup_key).first()
            if blob:
                try:
                    db.delete(blob)
                    db.commit()
                    logger.info("Deleted image blob: %s (by user %s)", lookup_key, current_user.id)
                except SQLAlchemyError as exc:
                    db.rollback()
                    logger.error("Failed to delete image blob: %s", exc)
                    raise HTTPException(
                        status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
                        detail="Image deletion failed.",
                    ) from exc

    # Remove the upload record regardless of storage mode.
    if lookup_key is not None:
        record = db.query(UploadRecord).filter(UploadRecord.key == lookup_key).first()
        if record:
            try:
                db.delete(record)
                db.commit()
            except SQLAlchemyError:
                db.rollback()

    return {"message": "Image deleted"}
