"""WebSocket endpoints for real-time chat and notifications."""
import logging
from typing import Dict, Set

from fastapi import APIRouter, WebSocket, WebSocketDisconnect

router = APIRouter(tags=["websocket"])
logger = logging.getLogger(__name__)


class ConnectionManager:
    """Track active WebSocket connections keyed by user_id and room_id."""

    def __init__(self):
        # user_id -> set of websocket connections (notifications)
        self._user_connections: Dict[int, Set[WebSocket]] = {}
        # room_id -> set of websocket connections (chat)
        self._room_connections: Dict[str, Set[WebSocket]] = {}

    async def connect_user(self, user_id: int, ws: WebSocket):
        await ws.accept()
        self._user_connections.setdefault(user_id, set()).add(ws)
        logger.info("WS connected user_id=%s", user_id)

    def disconnect_user(self, user_id: int, ws: WebSocket):
        conns = self._user_connections.get(user_id, set())
        conns.discard(ws)
        if not conns:
            self._user_connections.pop(user_id, None)
        logger.info("WS disconnected user_id=%s", user_id)

    async def send_to_user(self, user_id: int, message: dict):
        for ws in set(self._user_connections.get(user_id, set())):
            try:
                await ws.send_json(message)
            except Exception:
                self.disconnect_user(user_id, ws)

    async def connect_room(self, room_id: str, ws: WebSocket):
        await ws.accept()
        self._room_connections.setdefault(room_id, set()).add(ws)
        logger.info("WS connected room=%s", room_id)

    def disconnect_room(self, room_id: str, ws: WebSocket):
        conns = self._room_connections.get(room_id, set())
        conns.discard(ws)
        if not conns:
            self._room_connections.pop(room_id, None)

    async def broadcast_room(self, room_id: str, message: dict, exclude: WebSocket = None):
        for ws in set(self._room_connections.get(room_id, set())):
            if ws is exclude:
                continue
            try:
                await ws.send_json(message)
            except Exception:
                self.disconnect_room(room_id, ws)


manager = ConnectionManager()


@router.websocket("/ws/chat/{room_id}")
async def ws_chat(websocket: WebSocket, room_id: str):
    """Real-time chat websocket for a conversation room.

    Clients send JSON messages:
      {"type": "message", "body": "...", "sender_id": 123}
      {"type": "typing", "user_id": 123}
      {"type": "read", "message_id": 456, "user_id": 123}
    """
    await manager.connect_room(room_id, websocket)
    try:
        while True:
            data = await websocket.receive_json()
            msg_type = data.get("type", "message")

            if msg_type == "typing":
                await manager.broadcast_room(
                    room_id,
                    {"type": "typing", "user_id": data.get("user_id")},
                    exclude=websocket,
                )
            elif msg_type == "read":
                await manager.broadcast_room(
                    room_id,
                    {"type": "read", "message_id": data.get("message_id"), "user_id": data.get("user_id")},
                    exclude=websocket,
                )
            else:
                # Broadcast message to all room members
                await manager.broadcast_room(room_id, data, exclude=websocket)

    except WebSocketDisconnect:
        manager.disconnect_room(room_id, websocket)


@router.websocket("/ws/notifications/{user_id}")
async def ws_notifications(websocket: WebSocket, user_id: int):
    """Real-time notification websocket for a user."""
    await manager.connect_user(user_id, websocket)
    try:
        while True:
            # Keep connection alive; server pushes notifications
            await websocket.receive_text()
    except WebSocketDisconnect:
        manager.disconnect_user(user_id, websocket)
