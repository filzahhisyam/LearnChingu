from __future__ import annotations

import random
from datetime import datetime, timezone

from fastapi import APIRouter, Depends

from app.dependencies import get_current_token, get_current_user, get_supabase_for_user
from app.exceptions import AppError
from app.schemas.quiz import QuizAnswerRequest, QuizStartRequest
from app.services.adaptive_engine import pick_next_question, recalculate_mastery

router = APIRouter()


@router.post("/start")
def start_quiz(
    payload: QuizStartRequest,
    current_user=Depends(get_current_user),
    token: str = Depends(get_current_token),
):
    supabase = get_supabase_for_user(token)

    topic_id = payload.topic_id
    if not topic_id:
        performance_response = (
            supabase.table("topic_performances")
            .select("topic_id, mastery_score")
            .eq("user_id", current_user.id)
            .order("mastery_score", desc=False)
            .limit(1)
            .execute()
        )
        weakest = (performance_response.data or [None])[0]
        topic_id = weakest["topic_id"] if weakest else None

    if not topic_id:
        profile_response = (
            supabase.table("student_profiles")
            .select("form_level")
            .eq("user_id", current_user.id)
            .maybe_single()
            .execute()
        )
        form_level = (profile_response.data or {}).get("form_level", "FORM_4")
        topics_response = supabase.table("topics").select("id").eq("form_level", form_level).execute()
        topics = topics_response.data or []
        if not topics:
            raise AppError(404, "No topics available")
        topic_id = random.choice(topics)["id"]

    topic_response = supabase.table("topics").select("id, name, code").eq("id", topic_id).maybe_single().execute()
    topic = topic_response.data
    if not topic:
        raise AppError(404, "Topic not found")

    session_response = supabase.table("quiz_sessions").insert({"user_id": current_user.id, "topic_id": topic_id}).execute()
    session = (session_response.data or [{}])[0]
    return {"session_id": session.get("id"), "topic": topic}


@router.get("/next-question/{session_id}")
def next_question(
    session_id: str,
    current_user=Depends(get_current_user),
    token: str = Depends(get_current_token),
):
    supabase = get_supabase_for_user(token)

    session_response = (
        supabase.table("quiz_sessions")
        .select("id, topic_id")
        .eq("id", session_id)
        .eq("user_id", current_user.id)
        .maybe_single()
        .execute()
    )
    session = session_response.data
    if not session:
        raise AppError(404, "Session not found")

    attempts_response = (
        supabase.table("quiz_attempts")
        .select("question_id")
        .eq("session_id", session_id)
        .execute()
    )
    attempted_ids = [row["question_id"] for row in (attempts_response.data or [])]

    question = pick_next_question(supabase, current_user.id, session["topic_id"], attempted_ids)
    if not question:
        return {"finished": True}

    question.pop("correct_answer", None)
    return {"question": question}


@router.post("/answer")
def answer_quiz(
    payload: QuizAnswerRequest,
    current_user=Depends(get_current_user),
    token: str = Depends(get_current_token),
):
    supabase = get_supabase_for_user(token)

    question_response = (
        supabase.table("questions")
        .select("id, topic_id, correct_answer, explanation")
        .eq("id", payload.question_id)
        .maybe_single()
        .execute()
    )
    question = question_response.data
    if not question:
        raise AppError(404, "Question not found")

    is_correct = payload.user_answer.strip().lower() == str(question["correct_answer"]).strip().lower()

    supabase.table("quiz_attempts").insert(
        {
            "session_id": payload.session_id,
            "question_id": payload.question_id,
            "user_answer": payload.user_answer,
            "is_correct": is_correct,
            "time_spent_seconds": payload.time_spent_seconds,
        }
    ).execute()

    performance_response = (
        supabase.table("topic_performances")
        .select("id, correct_count, attempt_count")
        .eq("user_id", current_user.id)
        .eq("topic_id", question["topic_id"])
        .maybe_single()
        .execute()
    )
    existing = performance_response.data or {}
    correct_count = int(existing.get("correct_count", 0)) + (1 if is_correct else 0)
    attempt_count = int(existing.get("attempt_count", 0)) + 1
    mastery_score = recalculate_mastery(correct_count, attempt_count)

    supabase.table("topic_performances").upsert(
        {
            "user_id": current_user.id,
            "topic_id": question["topic_id"],
            "correct_count": correct_count,
            "attempt_count": attempt_count,
            "mastery_score": mastery_score,
            "last_attempt_at": datetime.now(timezone.utc).isoformat(),
        },
        on_conflict="user_id,topic_id",
    ).execute()

    return {"is_correct": is_correct, "correct_answer": question["correct_answer"], "explanation": question["explanation"]}


@router.post("/end/{session_id}")
def end_quiz(
    session_id: str,
    current_user=Depends(get_current_user),
    token: str = Depends(get_current_token),
):
    supabase = get_supabase_for_user(token)

    session_response = (
        supabase.table("quiz_sessions")
        .select("id")
        .eq("id", session_id)
        .eq("user_id", current_user.id)
        .maybe_single()
        .execute()
    )
    if not session_response.data:
        raise AppError(404, "Session not found")

    attempts_response = supabase.table("quiz_attempts").select("is_correct").eq("session_id", session_id).execute()
    attempts = attempts_response.data or []
    total_attempts = len(attempts)
    correct_count = sum(1 for attempt in attempts if attempt["is_correct"])
    score = round(correct_count / total_attempts, 3) if total_attempts else 0.0

    supabase.table("quiz_sessions").update(
        {"completed_at": datetime.now(timezone.utc).isoformat(), "score": score}
    ).eq("id", session_id).execute()

    return {"score": score, "total_attempts": total_attempts, "correct_count": correct_count}
