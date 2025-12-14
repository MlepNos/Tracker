from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from app.api import router

app = FastAPI(title="Collector Lists API")

# For dev: allow Flutter web dev server + localhost
origins = [
    "http://localhost",
    "http://localhost:8000",
    "http://localhost:53471",  # your Flutter web port (adjust if it changes)
    "http://127.0.0.1:53471",
]

app.add_middleware(
    CORSMiddleware,
    allow_origin_regex=r"^http://(localhost|127\.0\.0\.1)(:\d+)?$",
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

@app.get("/health")
def health():
    return {"status": "ok"}

app.include_router(router)
