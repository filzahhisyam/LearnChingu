from pydantic import BaseModel, Field


class DiagnosticAttempt(BaseModel):
    question_id: str
    user_answer: str
    time_spent_seconds: int = Field(ge=0)


class DiagnosticSubmitRequest(BaseModel):
    attempts: list[DiagnosticAttempt]

