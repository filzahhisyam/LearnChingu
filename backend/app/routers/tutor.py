from __future__ import annotations

from fastapi import APIRouter, Depends

from app.dependencies import get_current_token, get_current_user, get_supabase_for_user
from app.exceptions import AppError
from app.schemas.tutor import TutorMessageRequest
from app.services.claude_service import send_tutor_message

router = APIRouter()


@router.post("/message")
def send_message(
    payload: TutorMessageRequest,
    current_user=Depends(get_current_user),
    token: str = Depends(get_current_token),
):
    supabase = get_supabase_for_user(token)

    session = None
    if payload.session_id:
        session_response = (
            supabase.table("tutoring_sessions")
            .select("id, messages")
            .eq("id", payload.session_id)
            .maybe_single()
            .execute()
        )
        session = session_response.data

    if not session:
        session_response = supabase.table("tutoring_sessions").insert({"user_id": current_user.id, "messages": []}).execute()
        session = (session_response.data or [{}])[0]

    messages = session.get("messages") or []
    messages.append({"role": "user", "content": payload.message})

    weak_topics_response = (
        supabase.table("topic_performances")
        .select("topic_id, mastery_score, topics(name)")
        .eq("user_id", current_user.id)
        .order("mastery_score", desc=False)
        .limit(3)
        .execute()
    )
    weak_topics_rows = weak_topics_response.data or []
    weak_topics = ", ".join((row.get("topics") or {}).get("name", "") for row in weak_topics_rows if row.get("topics"))

    conversation_history = [{"role": item["role"], "content": item["content"]} for item in messages]

    try:
        reply = send_tutor_message(conversation_history=conversation_history, weak_topics=weak_topics)
    except Exception:
        raise AppError(503, "AI service is temporarily unavailable. Please try again shortly.")

    messages.append({"role": "assistant", "content": reply})
    supabase.table("tutoring_sessions").update({"messages": messages}).eq("id", session["id"]).execute()

    return {"session_id": session["id"], "reply": reply, "message_count": len(messages)}


@router.get("/session/{session_id}")
def get_session(
    session_id: str,
    current_user=Depends(get_current_user),
    token: str = Depends(get_current_token),
):
    supabase = get_supabase_for_user(token)
    session_response = (
        supabase.table("tutoring_sessions")
        .select("id, messages, created_at, updated_at")
        .eq("id", session_id)
        .eq("user_id", current_user.id)
        .maybe_single()
        .execute()
    )
    session = session_response.data
    if not session:
        raise AppError(404, "Session not found")
    return {
        "session_id": session["id"],
        "messages": session.get("messages") or [],
        "created_at": session["created_at"],
        "updated_at": session["updated_at"],
    }
