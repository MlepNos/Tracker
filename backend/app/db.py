from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker, Session

# inside docker network: hostname is "db"
DATABASE_URL_DOCKER = "postgresql+psycopg://app:app@db:5432/collector"

engine = create_engine(DATABASE_URL_DOCKER, pool_pre_ping=True)

SessionLocal = sessionmaker(bind=engine, autoflush=False, autocommit=False)

def get_db() -> Session:
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()
