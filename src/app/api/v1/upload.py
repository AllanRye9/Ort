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

Render default bucket environment variables (checked second)
------------------------------------------------------------
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
"""

import io
import asyncio
import logging
import os
import uuid
from typing import List

from fastapi import APIRouter, HTTPException, Query, UploadFile, File, status

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/upload", tags=["upload"])

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

    # ── Render default bucket vars: BUCKET_* ────────────────────────────────
    bucket_key_id = os.getenv("BUCKET_ACCESS_KEY_ID")
    bucket_secret = os.getenv("BUCKET_SECRET_ACCESS_KEY")
    bucket_name = os.getenv("BUCKET_NAME")

    if bucket_key_id and bucket_secret and bucket_name:
        endpoint_url = os.getenv("BUCKET_ENDPOINT_URL")
        region = os.getenv("BUCKET_REGION", "us-east-1")
        public_base = os.getenv("S3_PUBLIC_BASE_URL", "").rstrip("/")
        if not public_base and endpoint_url:
            public_base = f"{endpoint_url.rstrip('/')}/{bucket_name}"
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
        public_base = os.getenv("S3_PUBLIC_BASE_URL", "").rstrip("/")
        if not public_base:
            region = os.getenv("AWS_REGION", "us-east-1")
            public_base = f"https://{bucket}.s3.{region}.amazonaws.com"
        return {
            "key_id": key_id,
            "secret": secret,
            "endpoint_url": os.getenv("S3_ENDPOINT_URL"),
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


async def _process_upload(file: UploadFile) -> dict:
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

    object_key = f"listings/{uuid.uuid4()}.{ext}"

    s3, bucket, public_base = _get_s3_client()

    if s3 and bucket:
        try:
            s3.upload_fileobj(
                io.BytesIO(contents),
                bucket,
                object_key,
                ExtraArgs={"ContentType": file.content_type, "ACL": "public-read"},
            )
            if not public_base:
                public_base = f"https://{bucket}.s3.amazonaws.com"
            url = f"{public_base}/{object_key}"
            logger.info("Uploaded image to S3 key: %s", object_key)
            return {"url": url}
        except Exception as exc:
            logger.error("S3 upload failed: %s", exc)
            raise HTTPException(
                status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
                detail="Image upload failed. Please try again.",
            ) from exc
    else:
        # Stub mode – S3 is not configured.  Save the file to disk so that
        # the /static/listings/ URL we return actually resolves.
        from pathlib import Path
        static_dir = Path(__file__).parents[4] / "static"
        save_path = static_dir / object_key
        save_path.parent.mkdir(parents=True, exist_ok=True)
        try:
            save_path.write_bytes(contents)
        except OSError as exc:
            logger.error("Failed to save image to disk: %s", exc)
            raise HTTPException(
                status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
                detail="Image upload failed. Please try again.",
            ) from exc
        logger.warning(
            "S3 not configured – saved image locally at %s", save_path
        )
        base_url = os.getenv("APP_BASE_URL", "https://ort.up.railway.app")
        return {"url": f"{base_url}/static/{object_key}"}


@router.post("/image", status_code=status.HTTP_200_OK)
async def upload_image(
    file: UploadFile = File(...),
):
    """Upload a single image file and return its public URL."""
    return await _process_upload(file)


@router.post("/images", status_code=status.HTTP_200_OK)
async def upload_images(
    files: List[UploadFile] = File(...),
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
    results = await asyncio.gather(*[_process_upload(f) for f in files])
    return {"urls": [r["url"] for r in results]}


@router.delete("/image", status_code=status.HTTP_200_OK)
async def delete_image(url: str = Query(..., description="Public URL of the image to delete")):
    """Delete an uploaded image by its public URL.

    Removes the object from S3 / Railway bucket when storage is configured.
    In stub mode, removes the file from the local static directory.
    """
    from pathlib import Path
    import urllib.parse

    s3, bucket, public_base = _get_s3_client()

    if s3 and bucket and public_base:
        # Derive the S3 object key from the public URL.
        # public_base ends without slash; URL = public_base + "/" + object_key
        if not url.startswith(public_base):
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="URL does not belong to the configured storage bucket.",
            )
        object_key = url[len(public_base):].lstrip("/")
        try:
            s3.delete_object(Bucket=bucket, Key=object_key)
            logger.info("Deleted S3 object: %s", object_key)
            return {"message": "Image deleted"}
        except Exception as exc:
            logger.error("S3 delete failed: %s", exc)
            raise HTTPException(
                status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
                detail="Image deletion failed. Please try again.",
            ) from exc
    else:
        # Stub mode: delete from local static directory
        base_url = os.getenv("APP_BASE_URL", "https://ort.up.railway.app")
        static_prefix = f"{base_url}/static/"
        if url.startswith(static_prefix):
            rel_path = url[len(static_prefix):]
            static_dir = Path(__file__).parents[4] / "static"
            target = (static_dir / rel_path).resolve()
            # Safety: ensure the resolved path is still inside static_dir
            if not str(target).startswith(str(static_dir.resolve())):
                raise HTTPException(
                    status_code=status.HTTP_400_BAD_REQUEST,
                    detail="Invalid image URL.",
                )
            if target.exists():
                try:
                    target.unlink()
                    logger.info("Deleted local image: %s", target)
                except OSError as exc:
                    logger.error("Failed to delete local image: %s", exc)
                    raise HTTPException(
                        status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
                        detail="Image deletion failed.",
                    ) from exc
        return {"message": "Image deleted"}
