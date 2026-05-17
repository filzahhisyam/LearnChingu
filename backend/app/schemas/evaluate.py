from pydantic import BaseModel


class WorkingEvaluationRequest(BaseModel):
    question_id: str | None = None
    question_content: str
    image_base64: str

