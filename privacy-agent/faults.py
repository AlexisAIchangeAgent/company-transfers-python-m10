"""Training material. Fault switch for cycle 3 of M10 (observe + diagnose).

Set the environment variable PRIVACY_AGENT_FAULT to one mode, run the agent, read the trace.
Unset it for a normal run. Without the variable, every function below changes nothing.

    mode            what goes wrong                                   class to find
    tool_error      the write tool fails with PermissionError         tool
    tool_timeout    the read tool takes 30 seconds                    tool or execution control
    drop_identity   the read tool returns the request without its
                    "identity" field                                  context
    stale_policy    the agent loads faults/policy-v1.1.md, an old
                    version of the policy, instead of policy.md        contract
    low_turns       the turn budget of a session is 1                 execution control

The agent must call these functions at the right places: before each tool runs, on each request
it reads, when it loads the policy, and when it sets its turn budget. Wiring them in is part of
the cycle.
"""

from __future__ import annotations

import os
import time
from pathlib import Path
from typing import Any

ENV_VAR = "PRIVACY_AGENT_FAULT"
MODES = ("tool_error", "tool_timeout", "drop_identity", "stale_policy", "low_turns")
STALE_POLICY = Path(__file__).resolve().parent / "faults" / "policy-v1.1.md"
TIMEOUT_SECONDS = 30


def active() -> str | None:
    """The fault mode switched on, or None. An unknown mode is an error, not a silent no-op."""
    mode = os.environ.get(ENV_VAR, "").strip()
    if not mode:
        return None
    if mode not in MODES:
        raise ValueError(f"{ENV_VAR}={mode!r} is not one of {', '.join(MODES)}")
    return mode


def before_tool(tool_name: str, *, writes: bool) -> None:
    """Call at the start of each tool. `writes` is True for a tool that changes a state."""
    mode = active()
    if mode == "tool_error" and writes:
        raise PermissionError(f"fault {mode}: {tool_name} cannot write")
    if mode == "tool_timeout" and not writes:
        time.sleep(TIMEOUT_SECONDS)


def filter_request(request: dict[str, Any]) -> dict[str, Any]:
    """Call on each request the read tool returns."""
    if active() == "drop_identity":
        return {k: v for k, v in request.items() if k != "identity"}
    return request


def policy_path(default: Path) -> Path:
    """Call where the agent loads its policy."""
    return STALE_POLICY if active() == "stale_policy" else default


def max_turns(default: int) -> int:
    """Call where the agent sets the turn budget of a session."""
    return 1 if active() == "low_turns" else default
