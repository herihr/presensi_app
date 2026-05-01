from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session

from core.database import get_db
from schemas.embedding_schema import EmbeddingCreate
from services.embedding_service import EmbeddingService

router = APIRouter()
@router.post("/")
def create_embedding(data: EmbeddingCreate, db: Session = Depends(get_db)):
    return EmbeddingService.create_embedding(
        db,
        data.siswa_id,
        data.embedding
    )


@router.get("/")
def get_embeddings(db: Session = Depends(get_db)):
    return EmbeddingService.get_all_embeddings(db)