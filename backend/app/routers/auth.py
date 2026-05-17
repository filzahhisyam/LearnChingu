from __future__ import annotations

from fastapi import APIRouter, Depends
from pydantic import BaseModel
from supabase import Client

from app.dependencies import get_current_token, get_current_user, get_supabase, get_supabase_admin
from app.exceptions import AppError

router = APIRouter()


# ---------------------------------------------------------------------------
# Schemas (inline to avoid dependency on missing schema files)
# ---------------------------------------------------------------------------

class RegisterRequest(BaseModel):
    email: str
    password: str
    name: str
    form_level: int
    confidence_level: int = 3


class LoginRequest(BaseModel):
    email: str
    password: str


# ---------------------------------------------------------------------------
# POST /api/auth/register
# ---------------------------------------------------------------------------

@router.post("/register")
def register(
    payload: RegisterRequest,
    supabase: Client = Depends(get_supabase),
    admin: Client = Depends(get_supabase_admin),
):
    try:
        # 1. Create user in Supabase Auth
        auth_result = supabase.auth.sign_up({
            "email": payload.email,
            "password": payload.password,
        })
        user = getattr(auth_result, "user", None)
        if user is None:
            raise AppError(409, "Email already exists")

        # 2. Insert into profiles table
        admin.table("profiles").upsert({
            "id": user.id,
            "email": payload.email,
            "username": payload.name,
            "level": "beginner",
        }).execute()

        # 3. Insert into students table
        admin.table("students").upsert({
            "id": user.id,
            "name": payload.name,
            "form_level": payload.form_level,
            "confidence_level": payload.confidence_level,
        }).execute()

        return {
            "user": {
                "id": user.id,
                "email": user.email,
                "name": payload.name,
                "form_level": payload.form_level,
            }
        }

    except AppError:
        raise
    except Exception as e:
        print(f"REGISTER ERROR: {e}")
        raise AppError(409, str(e))


# ---------------------------------------------------------------------------
# POST /api/auth/login
# ---------------------------------------------------------------------------

@router.post("/login")
def login(
    payload: LoginRequest,
    supabase: Client = Depends(get_supabase),
    admin: Client = Depends(get_supabase_admin),
):
    try:
        # 1. Sign in via Supabase Auth
        auth_result = supabase.auth.sign_in_with_password({
            "email": payload.email,
            "password": payload.password,
        })
        session = getattr(auth_result, "session", None)
        user = getattr(auth_result, "user", None)

        if session is None or user is None:
            raise AppError(401, "Invalid credentials")

        # 2. Fetch student profile for name and form_level
        student_response = (
            admin.table("students")
            .select("name, form_level")
            .eq("id", user.id)
            .maybe_single()
            .execute()
        )
        student = student_response.data or {}

        # 3. Fetch profile for level
        profile_response = (
            admin.table("profiles")
            .select("level")
            .eq("id", user.id)
            .maybe_single()
            .execute()
        )
        profile = profile_response.data or {}

        return {
            "access_token": session.access_token,
            "user": {
                "id": user.id,
                "email": user.email,
                "name": student.get("name", ""),
                "form_level": student.get("form_level"),
                "level": profile.get("level", "beginner"),
            },
        }

    except AppError:
        raise
    except Exception:
        raise AppError(401, "Invalid credentials")


# ---------------------------------------------------------------------------
# GET /api/auth/me
# ---------------------------------------------------------------------------

@router.get("/me")
def me(
    current_user=Depends(get_current_user),
    token: str = Depends(get_current_token),
    admin: Client = Depends(get_supabase_admin),
):
    student_response = (
        admin.table("students")
        .select("name, form_level, confidence_level")
        .eq("id", current_user.id)
        .maybe_single()
        .execute()
    )
    student = student_response.data
    if not student:
        raise AppError(404, "Student profile not found")

    profile_response = (
        admin.table("profiles")
        .select("username, level")
        .eq("id", current_user.id)
        .maybe_single()
        .execute()
    )
    profile = profile_response.data or {}

    return {
        "id": current_user.id,
        "email": current_user.email,
        "name": student.get("name", ""),
        "form_level": student.get("form_level"),
        "confidence_level": student.get("confidence_level"),
        "level": profile.get("level", "beginner"),
    }