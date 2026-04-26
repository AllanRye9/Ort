"""Background analytics tasks."""
import logging
from datetime import date

from .celery_app import celery_app

logger = logging.getLogger(__name__)


@celery_app.task(name="app.tasks.analytics.record_upload_event")
def record_upload_event(user_id: int, image_url: str):
    """Record an image upload event for analytics."""
    logger.info("Upload event: user_id=%s url=%s", user_id, image_url)


@celery_app.task(name="app.tasks.analytics.reset_daily_challenges")
def reset_daily_challenges():
    """Reset daily challenge progress for all users at midnight UTC."""
    from app.database.database import local_session
    from app.models.gamification_models import UserChallengeProgress

    db = local_session()
    try:
        today = date.today()
        # Clear incomplete progress from previous days
        db.query(UserChallengeProgress).filter(
            UserChallengeProgress.completed_at == None,  # noqa: E711
        ).delete()
        db.commit()
        logger.info("Daily challenges reset for %s", today)
    finally:
        db.close()
