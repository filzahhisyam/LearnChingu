from __future__ import annotations

from fastapi import APIRouter, Depends
from pydantic import BaseModel

from app.dependencies import get_current_token, get_current_user, get_supabase_admin, get_supabase_for_user
from app.exceptions import AppError
from app.services.adaptive_engine import update_profile_level
from app.services.claude_service import evaluate_solution, translate_whiteboard

router = APIRouter()


# ---------------------------------------------------------------------------
# Request schemas (defined here to keep changes self-contained)
# ---------------------------------------------------------------------------

class TranslateRequest(BaseModel):
    question_id: str
    image_base64: str  # raw base64 PNG from Flutter whiteboard


class MarkRequest(BaseModel):
    question_id: str
    extracted_text: str   # confirmed transcription from /translate step
    image_base64: str     # same whiteboard PNG, for Claude to cross-reference


# ---------------------------------------------------------------------------
# POST /api/evaluate/translate
# ---------------------------------------------------------------------------

@router.post("/translate")
def translate(
    payload: TranslateRequest,
    current_user=Depends(get_current_user),
    token: str = Depends(get_current_token),
):
    """
    Step 1 — Whiteboard translation.

    Fetches the question image from Supabase for context, then sends both
    the question image and the student's whiteboard PNG to Claude Vision.
    Returns the extracted math text for the student to confirm before marking.

    Flutter should show this to the student and allow corrections before
    calling /api/evaluate/mark.
    """
    supabase = get_supabase_for_user(token)

    # Fetch question to get the question image URL for context
    question_response = (
        supabase
        .table("questions")
        .select("id, question_image_url")
        .eq("id", payload.question_id)
        .maybe_single()
        .execute()
    )
    question = question_response.data
    if not question:
        raise AppError(404, "Question not found")

    # Strip data URI prefix if Flutter sends it
    image_base64 = (
        payload.image_base64.split(",", 1)[1]
        if "," in payload.image_base64
        else payload.image_base64
    )

    try:
        extracted_text = translate_whiteboard(
            image_base64=image_base64,
            question_image_url=question.get("question_image_url"),
        )
    except Exception as e:
        raise AppError(503, str(e))

    return {"extracted_text": extracted_text}


# ---------------------------------------------------------------------------
# POST /api/evaluate/mark
# ---------------------------------------------------------------------------

@router.post("/mark")
def mark(
    payload: MarkRequest,
    current_user=Depends(get_current_user),
    token: str = Depends(get_current_token),
):
    """
    Step 2 — Evaluation and marking.

    Receives the student-confirmed extracted text and the original whiteboard image.
    Fetches the marking scheme image from Supabase, sends everything to Claude Vision,
    then:
      - Saves the result to student_attempts
      - Updates profiles.level via adaptive logic
      - Returns the full evaluation to Flutter
    """
    supabase = get_supabase_for_user(token)

    # Fetch question for marking scheme and marks available
    question_response = (
        supabase
        .table("questions")
        .select("id, marking_scheme_image_url, marks_available, topic")
        .eq("id", payload.question_id)
        .maybe_single()
        .execute()
    )
    question = question_response.data
    if not question:
        raise AppError(404, "Question not found")

    marking_scheme_url = question.get("marking_scheme_image_url")
    if not marking_scheme_url:
        raise AppError(422, "This question does not have a marking scheme yet.")

    marks_available = int(question.get("marks_available") or 1)

    # Strip data URI prefix if present
    image_base64 = (
        payload.image_base64.split(",", 1)[1]
        if "," in payload.image_base64
        else payload.image_base64
    )

    # Call Claude Vision for evaluation
    try:
        evaluation = evaluate_solution(
            extracted_text=payload.extracted_text,
            image_base64=image_base64,
            marking_scheme_image_url=marking_scheme_url,
            marks_available=marks_available,
        )
    except Exception:
        raise AppError(503, "AI service is temporarily unavailable. Please try again shortly.")

    # Auto-create student row if missing to prevent foreign key errors
    try:
        admin = get_supabase_admin()
        admin.table("students").upsert({
            "id": current_user.id,
            "name": current_user.email,
            "form_level": 4,
            "confidence_level": 3,
        }, on_conflict="id").execute()
    except Exception:
        pass  # Non-fatal

    # Persist to student_attempts
    attempt_insert = supabase.table("student_attempts").insert(
        {
            "student_id": current_user.id,
            "question_id": payload.question_id,
            "was_correct": evaluation.get("is_correct"),
            "marks_awarded": evaluation.get("marks_awarded", 0),
            "ai_feedback": evaluation.get("feedback", ""),
        }
    ).execute()

    attempt_id = (attempt_insert.data or [{}])[0].get("id")

    # Update profile level based on latest attempt history
    try:
        update_profile_level(current_user.id, supabase)
    except Exception:
        pass  # Non-fatal: don't fail the request if level update fails

    return {
        "attempt_id": attempt_id,
        "is_correct": evaluation.get("is_correct"),
        "marks_awarded": evaluation.get("marks_awarded", 0),
        "marks_available": marks_available,
        "steps_correct": evaluation.get("steps_correct", []),
        "errors": evaluation.get("errors", []),
        "feedback": evaluation.get("feedback", ""),
        "encouragement": evaluation.get("encouragement", "Keep it up!"),
    }