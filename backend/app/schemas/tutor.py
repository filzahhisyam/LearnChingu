from pydantic import BaseModel


class TutorMessageRequest(BaseModel):
    session_id: str | None = None
    message: str

