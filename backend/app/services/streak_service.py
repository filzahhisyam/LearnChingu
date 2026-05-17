from __future__ import annotations

from datetime import datetime, timedelta, timezone

from supabase import Client


def _to_kuala_lumpur_date(value: str | datetime) -> str:
    if isinstance(value, str):
        dt = datetime.fromisoformat(value.replace("Z", "+00:00"))
    else:
        dt = value
    kl_time = dt.astimezone(timezone(timedelta(hours=8)))
    return kl_time.date().isoformat()


def calculate_streak(user_id: str, supabase_client: Client) -> int:
    session_response = supabase_client.table("quiz_sessions").select("id").eq("user_id", user_id).execute()
    session_ids = [row["id"] for row in (session_response.data or [])]
    if not session_ids:
        return 0

    attempts_response = supabase_client.table("quiz_attempts").select("answered_at").in_("session_id", session_ids).execute()
    rows = attempts_response.data or []
    if not rows:
        return 0

    date_lookup = {_to_kuala_lumpur_date(row["answered_at"]) for row in rows}
    current = datetime.now(timezone(timedelta(hours=8))).date()
    streak = 0
    while current.isoformat() in date_lookup:
        streak += 1
        current = current - timedelta(days=1)
    return streak
