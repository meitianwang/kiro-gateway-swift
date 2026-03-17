# -*- coding: utf-8 -*-

"""
Routes for Claude Code client configuration.

Provides endpoints to read and write ~/.claude/settings.json,
allowing automatic configuration of Claude Code to use this gateway.
"""

import json
from pathlib import Path
from typing import Optional

from fastapi import APIRouter, HTTPException
from loguru import logger
from pydantic import BaseModel

from kiro.config import PROXY_API_KEY, SERVER_PORT


class ClaudeCodeConfig(BaseModel):
    opus_model: str = ""
    sonnet_model: str = ""
    haiku_model: str = ""


router = APIRouter(tags=["Claude Config"])

SETTINGS_PATH = Path.home() / ".claude" / "settings.json"


@router.get("/claude-config", response_model=Optional[ClaudeCodeConfig])
async def get_claude_code_config():
    """Read current Claude Code model config from ~/.claude/settings.json."""
    if not SETTINGS_PATH.exists():
        return None

    try:
        settings = json.loads(SETTINGS_PATH.read_text(encoding="utf-8"))
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Failed to read settings.json: {e}")

    env = settings.get("env")
    if not isinstance(env, dict):
        return None

    return ClaudeCodeConfig(
        opus_model=env.get("ANTHROPIC_DEFAULT_OPUS_MODEL", ""),
        sonnet_model=env.get("ANTHROPIC_DEFAULT_SONNET_MODEL", ""),
        haiku_model=env.get("ANTHROPIC_DEFAULT_HAIKU_MODEL", ""),
    )


@router.post("/claude-config")
async def save_claude_code_config(config: ClaudeCodeConfig):
    """Write Claude Code config to ~/.claude/settings.json."""
    claude_dir = SETTINGS_PATH.parent
    try:
        claude_dir.mkdir(parents=True, exist_ok=True)
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Failed to create .claude directory: {e}")

    # Read existing settings to preserve other fields
    if SETTINGS_PATH.exists():
        try:
            settings = json.loads(SETTINGS_PATH.read_text(encoding="utf-8"))
        except Exception:
            settings = {}
    else:
        settings = {}

    base_url = f"http://127.0.0.1:{SERVER_PORT}"

    settings["env"] = {
        "ANTHROPIC_AUTH_TOKEN": PROXY_API_KEY,
        "ANTHROPIC_BASE_URL": base_url,
        "ANTHROPIC_DEFAULT_OPUS_MODEL": config.opus_model,
        "ANTHROPIC_DEFAULT_SONNET_MODEL": config.sonnet_model,
        "ANTHROPIC_DEFAULT_HAIKU_MODEL": config.haiku_model,
        "API_TIMEOUT_MS": "3000000",
        "CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC": "1",
    }

    try:
        SETTINGS_PATH.write_text(
            json.dumps(settings, indent=2, ensure_ascii=False),
            encoding="utf-8",
        )
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Failed to write settings.json: {e}")

    logger.info(f"Claude Code config saved to {SETTINGS_PATH}")
    return {"status": "ok"}
