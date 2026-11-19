from app.core.errors import ApiError


def require(condition: bool, status_code: int, detail: str) -> None:
    if not condition:
        raise ApiError(status_code=status_code, detail=detail)
