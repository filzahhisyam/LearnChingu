from __future__ import annotations

from typing import Any

from supabase import Client

from app.services.mastery_calculator import calculate_mastery


def recalculate_mastery(correct_count: int, attempt_count: int) -> float:
    return calculate_mastery(correct_count, attempt_count)


# ---------------------------------------------------------------------------
# Difficulty targeting
# ---------------------------------------------------------------------------

def get_target_difficulty(student_id: str, topic: str, supabase_client: Client) -> int:
    """
    Look at the student's last 5 attempts on this topic (joined from student_attempts
    → questions on question_id) and return a target difficulty int: 1, 2, or 3.

    Accuracy thresholds:
      < 40%  correct → difficulty 1 (easy)
      40-70% correct → difficulty 2 (medium)
      > 70%  correct → difficulty 3 (hard)

    Falls back to difficulty 1 if no attempts exist yet.
    """
    # Join student_attempts with questions to filter by topic
    response = (
        supabase_client
        .table("student_attempts")
        .select("was_correct, questions!inner(topic, difficulty)")
        .eq("student_id", student_id)
        .eq("questions.topic", topic)
        .order("timestamp", desc=True)
        .limit(5)
        .execute()
    )
    rows = response.data or []

    if not rows:
        return 1  # No history → start easy

    correct = sum(1 for row in rows if row.get("was_correct") is True)
    accuracy = correct / len(rows)

    if accuracy < 0.4:
        return 1
    if accuracy <= 0.7:
        return 2
    return 3


# ---------------------------------------------------------------------------
# Profile level update
# ---------------------------------------------------------------------------

def update_profile_level(student_id: str, supabase_client: Client) -> None:
    """
    After each attempt, recalculate the student's overall level across all topics
    and update profiles.level accordingly.

    Uses last 10 attempts across ALL topics to gauge overall performance.

    Mapping:
      overall accuracy < 40%  → 'beginner'   (difficulty 1)
      overall accuracy 40-70% → 'intermediate' (difficulty 2)
      overall accuracy > 70%  → 'advanced'   (difficulty 3)
    """
    response = (
        supabase_client
        .table("student_attempts")
        .select("was_correct")
        .eq("student_id", student_id)
        .order("timestamp", desc=True)
        .limit(10)
        .execute()
    )
    rows = response.data or []

    if not rows:
        return  # Not enough data yet, leave profile level unchanged

    correct = sum(1 for row in rows if row.get("was_correct") is True)
    accuracy = correct / len(rows)

    if accuracy < 0.4:
        new_level = "beginner"
    elif accuracy <= 0.7:
        new_level = "intermediate"
    else:
        new_level = "advanced"

    supabase_client.table("profiles").update(
        {"level": new_level}
    ).eq("id", student_id).execute()


# ---------------------------------------------------------------------------
# Question picker
# ---------------------------------------------------------------------------

def pick_next_question(
    supabase_client: Client,
    student_id: str,
    topic: str,
    attempted_question_ids: list[str],
) -> dict[str, Any] | None:
    """
    Fetch the next question for this student on this topic.
    1. Get target difficulty from recent attempts.
    2. Try to find an unattempted question at that difficulty.
    3. If none found, fall back to any unattempted question in the topic.
    Returns None if all questions in the topic are exhausted.
    """
    target_difficulty = get_target_difficulty(student_id, topic, supabase_client)

    # Try target difficulty first
    response = (
        supabase_client
        .table("questions")
        .select(
            "id, question_text, question_image_url, topic, difficulty, "
            "marks_available, marking_scheme_image_url"
        )
        .eq("topic", topic)
        .eq("difficulty", target_difficulty)
        .execute()
    )
    available = [
        row for row in (response.data or [])
        if row["id"] not in attempted_question_ids
    ]
    if available:
        return available[0]

    # Fallback: any difficulty
    fallback_response = (
        supabase_client
        .table("questions")
        .select(
            "id, question_text, question_image_url, topic, difficulty, "
            "marks_available, marking_scheme_image_url"
        )
        .eq("topic", topic)
        .execute()
    )
    fallback_available = [
        row for row in (fallback_response.data or [])
        if row["id"] not in attempted_question_ids
    ]
    if fallback_available:
        return fallback_available[0]

    return None