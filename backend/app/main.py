from __future__ import annotations

from fastapi import FastAPI, Request
from fastapi.exceptions import RequestValidationError
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse

from app.exceptions import AppError
from app.middleware.request_logger import RequestLoggerMiddleware
from app.routers import auth, diagnostic, evaluate, progress, quiz, questions, tutor

app = FastAPI(title="LearnChingu API", version="1.0.0")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)
app.add_middleware(RequestLoggerMiddleware)


@app.exception_handler(AppError)
async def app_error_handler(request: Request, exc: AppError):
    return JSONResponse(status_code=exc.status_code, content={"error": exc.detail})


@app.exception_handler(RequestValidationError)
async def validation_error_handler(request: Request, exc: RequestValidationError):
    return JSONResponse(status_code=400, content={"error": "Validation failed", "details": exc.errors()})


@app.exception_handler(Exception)
async def generic_error_handler(request: Request, exc: Exception):
    return JSONResponse(status_code=500, content={"error": "Internal server error"})


app.include_router(auth.router, prefix="/api/auth", tags=["auth"])
app.include_router(diagnostic.router, prefix="/api/diagnostic", tags=["diagnostic"])
app.include_router(quiz.router, prefix="/api/quiz", tags=["quiz"])
app.include_router(evaluate.router, prefix="/api/evaluate", tags=["evaluate"])
app.include_router(tutor.router, prefix="/api/tutor", tags=["tutor"])
app.include_router(progress.router, prefix="/api/progress", tags=["progress"])
app.include_router(questions.router, prefix="/api/questions", tags=["questions"])


@app.get("/health")
def health():
    return {"status": "ok", "service": "LearnChingu API"}
