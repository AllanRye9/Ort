"""
Image upload endpoint.

Accepts a multipart/form-data POST with a single ``file`` field.
When AWS credentials are configured via environment variables the file is
uploaded to the configured S3-compatible bucket and the public URL is returned.
When credentials are absent (local / test environment) the endpoint returns a
stub URL so that the rest of the API still works.

Environment variables
---------------------
AWS_ACCESS_KEY_ID
AWS_SECRET_ACCESS_KEY
AWS_REGION          (default: us-east-1)
S3_BUCKET_NAME      Name of the bucket to upload to
S3_ENDPOINT_URL     Optional – set for S3-compatible services (e.g. Cloudflare R2)
S3_PUBLIC_BASE_URL  Public base URL to prefix uploaded keys with
                    (e.g. https://pub-xxx.r2.dev or https://bucket.s3.amazonaws.com)
"""

import io
import logging
import os
import uuid

from fastapi import APIRouter, HTTPException, UploadFile, File, status

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


def _get_s3_client():
    """Return a boto3 S3 client when credentials are configured, else None."""
    key_id = os.getenv("AWS_ACCESS_KEY_ID")
    secret = os.getenv("AWS_SECRET_ACCESS_KEY")
    if not key_id or not secret:
        return None
    try:
        import boto3

        kwargs = {
            "aws_access_key_id": key_id,
            "aws_secret_access_key": secret,
            "region_name": os.getenv("AWS_REGION", "us-east-1"),
        }
        endpoint_url = os.getenv("S3_ENDPOINT_URL")
        if endpoint_url:
            kwargs["endpoint_url"] = endpoint_url
        return boto3.client("s3", **kwargs)
    except ImportError:
        logger.warning("boto3 not installed – image upload will use stub mode")
        return None


@router.post("/image", status_code=status.HTTP_200_OK)
async def upload_image(
    file: UploadFile = File(...),
):
    """Upload an image file and return its public URL."""
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

    s3 = _get_s3_client()
    bucket = os.getenv("S3_BUCKET_NAME")

    if s3 and bucket:
        try:
            s3.upload_fileobj(
                io.BytesIO(contents),
                bucket,
                object_key,
                ExtraArgs={"ContentType": file.content_type, "ACL": "public-read"},
            )
            public_base = os.getenv("S3_PUBLIC_BASE_URL", "").rstrip("/")
            if not public_base:
                region = os.getenv("AWS_REGION", "us-east-1")
                public_base = f"https://{bucket}.s3.{region}.amazonaws.com"
            url = f"{public_base}/{object_key}"
            logger.info("Uploaded image to S3: %s", url)
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
        static_dir = os.path.join(
            os.path.dirname(os.path.dirname(os.path.dirname(os.path.dirname(os.path.dirname(__file__))))),
            "static",
        )
        save_path = os.path.join(static_dir, object_key)
        os.makedirs(os.path.dirname(save_path), exist_ok=True)
        try:
            with open(save_path, "wb") as f:
                f.write(contents)
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
