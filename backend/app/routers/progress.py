from __future__ import annotations

from fastapi import APIRouter, Depends

from app.dependencies import get_current_token, get_current_user, get_supabase_for_user
from app.exceptions import AppError
from app.services.streak_service import calculate_streak

router = APIRouter()


def mastery_level(score: float) -> str:
    if score < 0.4:
        return "weak"
    if score <= 0.7:
        return "developing"
    return "strong"


@router.get("/overview")
def overview(current_user=Depends(get_current_user), token: str = Depends(get_current_token)):
    supabase = get_supabase_for_user(token)

    performances_response = (
        supabase.table("topic_performances")
        .select("topic_id, correct_count, attempt_count, mastery_score, topics(id, name, code)")
        .eq("user_id", current_user.id)
        .execute()
    )
    performances = performances_response.data or []

    overall_mastery = round(
        sum(float(item["mastery_score"]) for item in performances) / len(performances), 3
    ) if performances else 0.0

    quiz_sessions_response = supabase.table("quiz_sessions").select("id").eq("user_id", current_user.id).execute()
    session_ids = [row["id"] for row in (quiz_sessions_response.data or [])]

    total_questions_attempted = 0
    total_correct = 0
    if session_ids:
        attempts_response = supabase.table("quiz_attempts").select("is_correct").in_("session_id", session_ids).execute()
        attempts = attempts_response.data or []
        total_questions_attempted = len(attempts)
        total_correct = sum(1 for attempt in attempts if attempt["is_correct"])

    sessions_completed_response = supabase.table("quiz_sessions").select("id, completed_at").eq("user_id", current_user.id).execute()
    sessions_completed_count = len([row for row in (sessions_completed_response.data or []) if row.get("completed_at") is not None])

    current_streak = calculate_streak(current_user.id, supabase)

    topic_breakdown = []
    for row in performances:
        topic = row.get("topics") or {}
        topic_breakdown.append(
            {
                "topic_id": row["topic_id"],
                "topic_name": topic.get("name"),
                "mastery_score": float(row["mastery_score"]),
                "mastery_level": mastery_level(float(row["mastery_score"])),
                "attempt_count": int(row["attempt_count"]),
                "correct_count": int(row["correct_count"]),
            }
        )

    return {
        "overall_mastery": overall_mastery,
        "total_questions_attempted": total_questions_attempted,
        "total_correct": total_correct,
        "sessions_completed": sessions_completed_count,
        "current_streak": current_streak,
        "topic_breakdown": topic_breakdown,
    }


@router.get("/topic/{topic_id}")
def topic_detail(topic_id: str, current_user=Depends(get_current_user), token: str = Depends(get_current_token)):
    supabase = get_supabase_for_user(token)

    topic_response = supabase.table("topics").select("id, name, code").eq("id", topic_id).maybe_single().execute()
    topic = topic_response.data
    if not topic:
        raise AppError(404, "Topic not found")

    performance_response = (
        supabase.table("topic_performances")
        .select("correct_count, attempt_count, mastery_score")
        .eq("user_id", current_user.id)
        .eq("topic_id", topic_id)
        .maybe_single()
        .execute()
    )
    performance = performance_response.data or {"correct_count": 0, "attempt_count": 0, "mastery_score": 0.0}

    question_ids_response = supabase.table("questions").select("id").eq("topic_id", topic_id).execute()
    question_ids = [row["id"] for row in (question_ids_response.data or [])]
    recent_attempts = []
    if question_ids:
        attempts_response = (
            supabase.table("quiz_attempts")
            .select("question_id, is_correct, answered_at, time_spent_seconds")
            .in_("question_id", question_ids)
            .order("answered_at", desc=True)
            .limit(10)
            .execute()
        )
        recent_attempts = attempts_response.data or []

    return {
        "topic": topic,
        "performance": {
            "mastery_score": float(performance["mastery_score"]),
            "correct_count": int(performance["correct_count"]),
            "attempt_count": int(performance["attempt_count"]),
            "mastery_level": mastery_level(float(performance["mastery_score"])),
        },
        "recent_attempts": recent_attempts,
    }
