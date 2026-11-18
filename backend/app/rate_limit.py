import time
from collections import defaultdict, deque
from threading import Lock

from fastapi import HTTPException, status


class SlidingWindowLimiter:
    def __init__(self, limit: int, window_seconds: int):
        self.limit = limit
        self.window_seconds = window_seconds
        self._events: dict[str, deque[float]] = defaultdict(deque)
        self._lock = Lock()

    def check(self, key: str) -> None:
        now = time.monotonic()

        with self._lock:
            events = self._events[key]
            cutoff = now - self.window_seconds

            while events and events[0] <= cutoff:
                events.popleft()

            if len(events) >= self.limit:
                raise HTTPException(
                    status_code=status.HTTP_429_TOO_MANY_REQUESTS,
                    detail="Too many requests",
                )

            events.append(now)


def client_key(request) -> str:
    forwarded = request.headers.get("X-Forwarded-For")
    if forwarded:
        # Only use this behind a trusted reverse proxy that overwrites the header.
        value = forwarded.split(",", 1)[0].strip()
    else:
        value = request.client.host if request.client else "unknown"

    return value
