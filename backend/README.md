# LearnChingu Backend

FastAPI backend for LearnChingu, an AI-powered SPM Mathematics tutoring app for Malaysian secondary school students.

## Stack

- FastAPI
- Supabase (PostgreSQL + Auth)
- Anthropic Claude API
- Pydantic v2
- Uvicorn

## Setup

1. Create a Supabase project and copy the URL, anon key, and service role key.
2. Copy `.env.example` to `.env` and fill in the values.
3. Open `supabase/seed.sql` in the Supabase SQL editor and run it to create tables, policies, topics, and sample questions.
4. Install dependencies:

```bash
pip install -r requirements.txt
```

5. Start the server:

```bash
uvicorn app.main:app --reload
```

By default the server runs on port `8000`.

## Notes

- Flutter should use Supabase Auth directly and send the JWT as `Authorization: Bearer <token>`.
- The backend uses the anon key for user-scoped operations and the service role key only for admin/seed-style operations.
- Claude failures return a friendly `503` response.
