from __future__ import annotations

from fastapi import APIRouter, Depends, Query

from app.dependencies import get_current_token, get_current_user, get_supabase_for_user
from app.exceptions import AppError
from app.services.adaptive_engine import pick_next_question

router = APIRouter()

# Full set of fields returned for every question — includes image URLs and marks
_QUESTION_FIELDS = (
    "id, question_text, question_image_url, marking_scheme_image_url, "
    "topic, difficulty, marks_available, created_at"
)


# ---------------------------------------------------------------------------
# GET /api/questions  (extended — was missing image/marks fields)
# ---------------------------------------------------------------------------

@router.get("")
def list_questions(
    topic: str | None = Query(default=None),
    difficulty: int | None = Query(default=None),
    current_user=Depends(get_current_user),
    token: str = Depends(get_current_token),
):
    """
    List questions with optional filtering by topic or difficulty.
    Now returns question_image_url, marking_scheme_image_url, marks_available.
    """
    supabase = get_supabase_for_user(token)
    query = supabase.table("questions").select(_QUESTION_FIELDS)

    if topic:
        query = query.eq("topic", topic)
    if difficulty is not None:
        query = query.eq("difficulty", difficulty)

    response = query.execute()
    return {"questions": response.data or []}


# ---------------------------------------------------------------------------
# GET /api/questions/next  (new endpoint)
# ---------------------------------------------------------------------------

@router.get("/next")
def next_question(
    topic: str = Query(..., description="Topic name to fetch a question for"),
    attempted_ids: str = Query(
        default="",
        description="Comma-separated list of already-attempted question IDs to exclude",
    ),
    current_user=Depends(get_current_user),
    token: str = Depends(get_current_token),
):
    """
    Adaptive next-question endpoint.

    1. Looks at the student's last 5 attempts on this topic (via student_attempts
       joined with questions) to determine target difficulty (1, 2, or 3).
    2. Returns an unattempted question at that difficulty.
    3. Falls back to any unattempted question in the topic if target difficulty
       is exhausted.
    4. Returns {"finished": true} if all questions in the topic are exhausted.

    Flutter should pass attempted_ids as a comma-separated string of UUIDs
    so the student doesn't see the same question twice in a session.
    """
    supabase = get_supabase_for_user(token)

    attempted_question_ids = (
        [qid.strip() for qid in attempted_ids.split(",") if qid.strip()]
        if attempted_ids
        else []
    )

    question = pick_next_question(
        supabase_client=supabase,
        student_id=current_user.id,
        topic=topic,
        attempted_question_ids=attempted_question_ids,
    )

    if not question:
        return {"finished": True, "question": None}

    return {"finished": False, "question": question}


# ---------------------------------------------------------------------------
# GET /api/questions/{question_id}  (extended — was missing image/marks fields)
# ---------------------------------------------------------------------------

@router.get("/{question_id}")
def get_question(
    question_id: str,
    current_user=Depends(get_current_user),
    token: str = Depends(get_current_token),
):
    """
    Fetch a single question by ID.
    Now returns question_image_url, marking_scheme_image_url, marks_available.
    """
    supabase = get_supabase_for_user(token)
    response = (
        supabase
        .table("questions")
        .select(_QUESTION_FIELDS)
        .eq("id", question_id)
        .maybe_single()
        .execute()
    )
    question = response.data
    if not question:
        raise AppError(404, "Question not found")
    return question