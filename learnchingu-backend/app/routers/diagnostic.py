from __future__ import annotations

import random
from collections import defaultdict
from datetime import datetime, timezone

from fastapi import APIRouter, Depends

from app.dependencies import get_current_token, get_current_user, get_supabase_for_user, get_supabase_admin
from app.exceptions import AppError
from app.schemas.diagnostic import DiagnosticSubmitRequest
from app.services.mastery_calculator import calculate_mastery

router = APIRouter()


def mastery_level_from_score(score: float) -> str:
    if score < 0.4:
        return "weak"
    if score <= 0.7:
        return "developing"
    return "strong"


@router.get("/questions")
def get_questions(current_user=Depends(get_current_user), token: str = Depends(get_current_token)):
    supabase = get_supabase_for_user(token)

    profile_response = (
        supabase.table("student_profiles")
        .select("form_level")
        .eq("user_id", current_user.id)
        .maybe_single()
        .execute()
    )
    profile = profile_response.data or {}
    form_level = profile.get("form_level")
    if not form_level:
        raise AppError(404, "Profile not found")

    questions_response = (
        supabase.table("questions")
        .select("id, topic_id, difficulty, type, content, options, is_diagnostic, topics(name)")
        .eq("is_diagnostic", True)
        .eq("form_level", form_level)
        .execute()
    )
    questions = questions_response.data or []

    grouped: dict[str, list[dict]] = defaultdict(list)
    for question in questions:
        grouped[question["topic_id"]].append(question)

    selected: list[dict] = []
    for topic_questions in grouped.values():
        easy = next((q for q in topic_questions if q["difficulty"] == "EASY"), None)
        medium = next((q for q in topic_questions if q["difficulty"] == "MEDIUM"), None)
        if easy:
            selected.append(easy)
        if medium:
            selected.append(medium)

    random.shuffle(selected)
    return {
        "questions": [
            {
                "id": question["id"],
                "topic_id": question["topic_id"],
                "topic_name": (question.get("topics") or {}).get("name"),
                "difficulty": question["difficulty"],
                "type": question["type"],
                "content": question["content"],
                "options": question["options"],
            }
            for question in selected[:20]
        ]
    }


@router.post("/submit")
def submit_diagnostic(
    payload: DiagnosticSubmitRequest,
    current_user=Depends(get_current_user),
    token: str = Depends(get_current_token),
):
    supabase = get_supabase_for_user(token)
    admin = get_supabase_admin()

    question_ids = [attempt.question_id for attempt in payload.attempts]
    question_response = (
        supabase.table("questions")
        .select("id, topic_id, correct_answer, topics(name)")
        .in_("id", question_ids)
        .execute()
    )
    questions = question_response.data or []
    question_map = {question["id"]: question for question in questions}

    topic_totals: dict[str, dict[str, int]] = defaultdict(lambda: {"correct": 0, "attempts": 0})
    total_correct = 0
    total_attempts = 0

    for attempt in payload.attempts:
        question = question_map.get(attempt.question_id)
        if not question:
            continue
        is_correct = attempt.user_answer.strip().lower() == str(question["correct_answer"]).strip().lower()
        topic_id = question["topic_id"]
        topic_totals[topic_id]["attempts"] += 1
        total_attempts += 1
        if is_correct:
            topic_totals[topic_id]["correct"] += 1
            total_correct += 1

    topic_breakdown: list[dict] = []
    for topic_id, counts in topic_totals.items():
        existing_response = (
            supabase.table("topic_performances")
            .select("correct_count, attempt_count")
            .eq("user_id", current_user.id)
            .eq("topic_id", topic_id)
            .maybe_single()
            .execute()
        )
        existing = existing_response.data or {}
        correct_count = int(existing.get("correct_count", 0)) + counts["correct"]
        attempt_count = int(existing.get("attempt_count", 0)) + counts["attempts"]
        mastery_score = calculate_mastery(correct_count, attempt_count)

        admin.table("topic_performances").upsert(
            {
                "user_id": current_user.id,
                "topic_id": topic_id,
                "correct_count": correct_count,
                "attempt_count": attempt_count,
                "mastery_score": mastery_score,
                "last_attempt_at": datetime.now(timezone.utc).isoformat(),
            },
            on_conflict="user_id,topic_id",
        ).execute()

        topic_name = next((question.get("topics", {}).get("name") for question in questions if question["topic_id"] == topic_id), None)
        topic_breakdown.append(
            {
                "topic_id": topic_id,
                "topic_name": topic_name,
                "score": mastery_score,
                "mastery_level": mastery_level_from_score(mastery_score),
            }
        )

    admin.table("student_profiles").update({"diagnostic_completed": True}).eq("user_id", current_user.id).execute()
    session_insert = admin.table("quiz_sessions").insert({"user_id": current_user.id}).execute()

    overall_score = round(total_correct / total_attempts, 3) if total_attempts else 0.0
    return {"overall_score": overall_score, "topic_breakdown": topic_breakdown, "session_id": (session_insert.data or [{}])[0].get("id")}
