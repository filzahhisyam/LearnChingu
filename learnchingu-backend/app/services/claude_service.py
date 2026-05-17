from __future__ import annotations

import json
from typing import Any

import httpx
from anthropic import Anthropic

from app.config import settings

client = Anthropic(api_key=settings.anthropic_api_key)


def _fetch_image_as_base64(url: str) -> tuple[str, str] | None:
    """Fetch a remote image and return (base64_string, media_type) or None on failure."""
    try:
        response = httpx.get(url, timeout=10)
        response.raise_for_status()
        import base64
        b64 = base64.b64encode(response.content).decode("utf-8")
        lower = url.lower()
        if lower.endswith(".jpg") or lower.endswith(".jpeg"):
            media_type = "image/jpeg"
        elif lower.endswith(".png"):
            media_type = "image/png"
        else:
            media_type = response.headers.get("content-type", "image/jpeg").split(";")[0]
        return b64, media_type
    except Exception:
        return None


def _sniff_media_type(image_base64: str) -> str:
    """Detect image/png vs image/jpeg from the base64 magic-byte prefix."""
    if image_base64.startswith("iVBORw0K"):
        return "image/png"
    return "image/jpeg"


def _parse_json_or_fallback(raw_text: str, fallback: dict[str, Any]) -> dict[str, Any]:
    try:
        cleaned = raw_text.strip()
        if cleaned.startswith("```"):
            cleaned = cleaned.split("\n", 1)[-1]
            cleaned = cleaned.rsplit("```", 1)[0]
        return json.loads(cleaned)
    except Exception:
        fallback["feedback"] = raw_text
        return fallback


def translate_whiteboard(image_base64: str, question_image_url: str | None, media_type: str | None = None) -> str:
    """
    Step 1 — Translation only.
    Sends the student's whiteboard PNG (base64) to Claude Vision.
    Also sends the question image for context if available.
    Returns the extracted math working as a plain string.
    """
    if media_type is None:
        media_type = _sniff_media_type(image_base64)
    content: list[dict[str, Any]] = []

    # Attach question image for context if available
    if question_image_url:
        result = _fetch_image_as_base64(question_image_url)
        if result:
            question_image_b64, question_media_type = result
            content.append({
                "type": "image",
                "source": {
                    "type": "base64",
                    "media_type": question_media_type,
                    "data": question_image_b64,
                },
            })
            content.append({
                "type": "text",
                "text": "This is the exam question the student was solving:",
            })

    # Attach student whiteboard
    content.append({
        "type": "image",
        "source": {
            "type": "base64",
            "media_type": media_type,
            "data": image_base64,
        },
    })
    content.append({
        "type": "text",
        "text": (
            "This is the student's handwritten working on the whiteboard.\n\n"
            "Your task: Transcribe exactly what the student has written. "
            "Preserve all mathematical expressions, steps, and working as faithfully as possible. "
            "Use plain text or simple LaTeX notation where needed. "
            "Do NOT evaluate or judge the answer — only transcribe what you see. "
            "If any part is unclear, transcribe your best reading and note it in square brackets e.g. [unclear]."
        ),
    })

    response = client.messages.create(
        model="claude-sonnet-4-5",
        max_tokens=1024,
        messages=[{"role": "user", "content": content}],
    )
    return response.content[0].text.strip()


def evaluate_solution(
    extracted_text: str,
    image_base64: str,
    marking_scheme_image_url: str,
    marks_available: int,
    media_type: str | None = None,
) -> dict[str, Any]:
    """
    Step 2 — Evaluation and marking.
    Sends the marking scheme image, the student's whiteboard image, and the
    confirmed extracted text to Claude Vision.
    Returns structured JSON with correctness, marks, and feedback.
    """
    if media_type is None:
        media_type = _sniff_media_type(image_base64)
    fallback: dict[str, Any] = {
        "is_correct": None,
        "marks_awarded": 0,
        "marks_available": marks_available,
        "steps_correct": [],
        "errors": [],
        "feedback": "Unable to evaluate. Please try again.",
        "encouragement": "Keep going, you are doing great!",
    }

    # Fetch marking scheme image
    marking_scheme_result = _fetch_image_as_base64(marking_scheme_image_url)
    if not marking_scheme_result:
        fallback["feedback"] = "Could not load the marking scheme. Please try again."
        return fallback
    marking_scheme_b64, marking_scheme_media_type = marking_scheme_result

    content: list[dict[str, Any]] = [
        # Marking scheme
        {
            "type": "image",
            "source": {
                "type": "base64",
                "media_type": marking_scheme_media_type,
                "data": marking_scheme_b64,
            },
        },
        {
            "type": "text",
            "text": "This is the official marking scheme for this question:",
        },
        # Student whiteboard
        {
            "type": "image",
            "source": {
                "type": "base64",
                "media_type": media_type,
                "data": image_base64,
            },
        },
        {
            "type": "text",
            "text": f"This is the student's handwritten working. Here is the transcribed version:\n\n{extracted_text}",
        },
        # Evaluation instruction
        {
            "type": "text",
            "text": (
                f"You are a patient, encouraging SPM Mathematics tutor for Malaysian students aged 15-17.\n\n"
                f"This question is worth {marks_available} marks.\n\n"
                "Compare the student's working against the marking scheme step by step. "
                "Award marks fairly based on the marking scheme. "
                "Never make the student feel bad. Always end on a positive note.\n\n"
                "Respond ONLY with a valid JSON object, no markdown fences, no extra text:\n"
                "{\n"
                '  "is_correct": boolean,\n'
                f'  "marks_awarded": integer between 0 and {marks_available},\n'
                f'  "marks_available": {marks_available},\n'
                '  "steps_correct": ["each correct step the student got right"],\n'
                '  "errors": [\n'
                "    {\n"
                '      "step": "what the student wrote",\n'
                '      "issue": "what is wrong",\n'
                '      "fix": "how to correct it"\n'
                "    }\n"
                "  ],\n"
                '  "feedback": "2-3 friendly sentences summarising their performance",\n'
                '  "encouragement": "one warm motivating sentence"\n'
                "}"
            ),
        },
    ]

    response = client.messages.create(
        model="claude-sonnet-4-5",
        max_tokens=1024,
        messages=[{"role": "user", "content": content}],
    )
    raw_text = response.content[0].text.strip()
    return _parse_json_or_fallback(raw_text, fallback)


def send_tutor_message(conversation_history: list[dict[str, Any]], weak_topics: str) -> str:
    """Existing tutor chat — unchanged."""
    response = client.messages.create(
        model="claude-sonnet-4-5",
        max_tokens=1024,
        system=(
            "You are Chingu, the friendly AI tutor for LearnChingu — an SPM Mathematics app for Malaysian students aged 15-17. "
            "You are warm, patient, and encouraging, like a smart study buddy.\n\n"
            "Never just give the answer. Guide students with hints and questions. Use simple language. Keep responses concise for an iPad screen.\n\n"
            f"This student's weakest topics right now: {weak_topics}. Give extra care if they ask about these."
        ),
        messages=conversation_history,
    )
    return response.content[0].text.strip()