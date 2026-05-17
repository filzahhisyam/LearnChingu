from pydantic import BaseModel


class ProgressTopicItem(BaseModel):
    topic_id: str
    topic_name: str
    mastery_score: float
    mastery_level: str
    attempt_count: int
    correct_count: int

