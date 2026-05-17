def calculate_mastery(correct_count: int, attempt_count: int) -> float:
    if attempt_count <= 0:
        return 0.0
    return max(0.0, min(1.0, round(correct_count / attempt_count, 3)))
