# -*- coding: utf-8 -*-

"""
In-memory request history for the macOS app UI.

Stores the last N request/response pairs so the Swift app can
fetch and display them when the user clicks a request log row.
"""

import json
import time
import threading
from collections import OrderedDict
from typing import Optional


class RequestHistory:
    """Thread-safe ring buffer of recent request details."""

    _instance = None

    def __new__(cls):
        if cls._instance is None:
            cls._instance = super().__new__(cls)
            cls._instance._initialized = False
        return cls._instance

    def __init__(self, max_entries: int = 50):
        if self._initialized:
            return
        self._lock = threading.Lock()
        self._entries: OrderedDict[str, dict] = OrderedDict()
        self._max = max_entries
        self._counter = 0
        self._initialized = True

    def new_request(self) -> str:
        """Create a new entry, return its ID."""
        with self._lock:
            self._counter += 1
            rid = f"req-{self._counter}"
            self._entries[rid] = {
                "id": rid,
                "timestamp": time.time(),
                "request_body": None,
                "kiro_request_body": None,
                "status": None,
                "model": None,
                "duration_ms": None,
            }
            # Evict oldest
            while len(self._entries) > self._max:
                self._entries.popitem(last=False)
            return rid

    def set_request_body(self, rid: str, body: bytes):
        with self._lock:
            if rid in self._entries:
                try:
                    self._entries[rid]["request_body"] = json.loads(body)
                except Exception:
                    self._entries[rid]["request_body"] = body.decode("utf-8", errors="replace")

    def set_kiro_request_body(self, rid: str, body: bytes):
        with self._lock:
            if rid in self._entries:
                try:
                    self._entries[rid]["kiro_request_body"] = json.loads(body)
                except Exception:
                    self._entries[rid]["kiro_request_body"] = body.decode("utf-8", errors="replace")

    def set_result(self, rid: str, status: int, model: str, duration_ms: float):
        with self._lock:
            if rid in self._entries:
                self._entries[rid]["status"] = status
                self._entries[rid]["model"] = model
                self._entries[rid]["duration_ms"] = duration_ms

    def get(self, rid: str) -> Optional[dict]:
        with self._lock:
            entry = self._entries.get(rid)
            if not entry:
                return None
            # Return a summary for the request body (messages count + system prompt preview)
            result = dict(entry)
            rb = result.get("request_body")
            if isinstance(rb, dict):
                messages = rb.get("messages", [])
                system = rb.get("system", "")
                # Build a readable summary
                result["summary"] = {
                    "model": rb.get("model", ""),
                    "stream": rb.get("stream", False),
                    "max_tokens": rb.get("max_tokens"),
                    "messages_count": len(messages),
                    "system_preview": _truncate(str(system), 500),
                    "messages": [_summarize_message(m) for m in messages[-10:]],  # last 10
                    "tools_count": len(rb.get("tools", [])),
                }
            return result

    def get_full_request(self, rid: str) -> Optional[dict]:
        """Return the full request body without summarization."""
        with self._lock:
            entry = self._entries.get(rid)
            if not entry:
                return None
            return dict(entry)

    def list_ids(self) -> list:
        with self._lock:
            return list(reversed(self._entries.keys()))


def _truncate(s: str, max_len: int) -> str:
    if len(s) <= max_len:
        return s
    return s[:max_len] + "..."


def _summarize_message(msg: dict) -> dict:
    """Summarize a single message for display."""
    role = msg.get("role", "")
    content = msg.get("content", "")

    if isinstance(content, str):
        preview = _truncate(content, 300)
    elif isinstance(content, list):
        # Collect text parts
        texts = []
        for part in content:
            if isinstance(part, dict):
                if part.get("type") == "text":
                    texts.append(part.get("text", ""))
                elif part.get("type") == "tool_use":
                    texts.append(f"[tool_use: {part.get('name', '?')}]")
                elif part.get("type") == "tool_result":
                    texts.append(f"[tool_result: {part.get('tool_use_id', '?')[:12]}]")
                else:
                    texts.append(f"[{part.get('type', '?')}]")
        preview = _truncate(" ".join(texts), 300)
    else:
        preview = str(content)[:300]

    return {"role": role, "preview": preview}


request_history = RequestHistory()
