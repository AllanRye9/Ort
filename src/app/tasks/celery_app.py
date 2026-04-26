"""Celery application instance and configuration."""
import os
from celery import Celery

REDIS_URL = os.getenv("REDIS_URL", "redis://localhost:6379/0")

celery_app = Celery(
    "ort_worker",
    broker=REDIS_URL,
    backend=REDIS_URL,
    include=[
        "app.tasks.media",
        "app.tasks.notifications",
        "app.tasks.analytics",
    ],
)

celery_app.conf.update(
    task_serializer="json",
    accept_content=["json"],
    result_serializer="json",
    timezone="UTC",
    enable_utc=True,
    beat_schedule={
        "reset-daily-challenges": {
            "task": "app.tasks.analytics.reset_daily_challenges",
            "schedule": 86400,  # every 24 hours
        },
    },
)
