"""Background tasks for sending notifications."""
import logging

from .celery_app import celery_app

logger = logging.getLogger(__name__)


@celery_app.task(name="app.tasks.notifications.send_push_notification")
def send_push_notification(user_id: int, title: str, body: str, data: dict = None):
    """Stub push notification task – replace with FCM/APNs integration."""
    logger.info(
        "Push notification to user_id=%s: %s – %s (data=%s)",
        user_id, title, body, data,
    )


@celery_app.task(name="app.tasks.notifications.notify_new_message")
def notify_new_message(recipient_id: int, sender_name: str, conversation_id: int):
    """Notify a user about a new chat message."""
    send_push_notification.delay(
        user_id=recipient_id,
        title=f"New message from {sender_name}",
        body="You have a new message",
        data={"type": "new_message", "conversation_id": conversation_id},
    )
