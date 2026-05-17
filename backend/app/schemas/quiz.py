from pydantic import BaseModel, Field


class QuizStartRequest(BaseModel):
    topic_id: str | None = None


class QuizAnswerRequest(BaseModel):
    session_id: str
    question_id: str
    user_answer: str
    time_spent_seconds: int = Field(ge=0)

