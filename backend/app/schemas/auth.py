from pydantic import BaseModel, EmailStr, Field


class RegisterRequest(BaseModel):
    email: EmailStr
    password: str = Field(min_length=6)
    name: str = Field(min_length=1)
    form_level: int
    confidence_level: int = Field(default=3, ge=1, le=5)


class LoginRequest(BaseModel):
    email: EmailStr
    password: str


class AuthUser(BaseModel):
    id: str
    email: EmailStr | None = None
    name: str
    form_level: int
    level: str = "beginner"


class AuthResponse(BaseModel):
    user: AuthUser


class LoginResponse(BaseModel):
    access_token: str
    user: AuthUser
