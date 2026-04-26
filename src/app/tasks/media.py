"""Background tasks for image/media processing."""
import logging
import os

from .celery_app import celery_app

logger = logging.getLogger(__name__)

REKOGNITION_ENABLED = bool(os.getenv("AWS_ACCESS_KEY_ID"))


@celery_app.task(name="app.tasks.media.moderate_image", bind=True, max_retries=3)
def moderate_image(self, image_id: int, image_url: str):
    """Call AWS Rekognition (or stub) to moderate an uploaded image.

    Updates the image record's moderation_status to 'approved' or 'rejected'
    and stores auto-generated tags in image_tags.
    """
    try:
        labels = []
        is_safe = True

        if REKOGNITION_ENABLED:
            import boto3

            client = boto3.client(
                "rekognition",
                region_name=os.getenv("AWS_REGION", "us-east-1"),
                aws_access_key_id=os.getenv("AWS_ACCESS_KEY_ID"),
                aws_secret_access_key=os.getenv("AWS_SECRET_ACCESS_KEY"),
            )
            # Detect moderation labels
            mod_response = client.detect_moderation_labels(
                Image={"S3Object": {"Bucket": os.getenv("S3_BUCKET_NAME", ""), "Name": image_url}},
                MinConfidence=70,
            )
            if mod_response.get("ModerationLabels"):
                is_safe = False

            # Detect regular labels for tagging
            label_response = client.detect_labels(
                Image={"S3Object": {"Bucket": os.getenv("S3_BUCKET_NAME", ""), "Name": image_url}},
                MaxLabels=10,
                MinConfidence=70,
            )
            labels = [lbl["Name"].lower() for lbl in label_response.get("Labels", [])]
        else:
            # Stub: mark as approved
            is_safe = True
            labels = []

        status = "approved" if is_safe else "rejected"

        # Persist via SQLAlchemy
        from app.database.database import local_session
        from app.models.gamification_models import ImageRecord

        db = local_session()
        try:
            rec = db.query(ImageRecord).filter(ImageRecord.id == image_id).first()
            if rec:
                rec.moderation_status = status
                rec.tags = labels
                db.commit()
        finally:
            db.close()

        logger.info("Moderation complete image_id=%s status=%s", image_id, status)
    except Exception as exc:
        logger.error("Moderation task failed for image_id=%s: %s", image_id, exc)
        raise self.retry(exc=exc, countdown=30)
