from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session

from core.database import get_db
from dependencies.auth import get_current_user, require_admin
from services.embedding_service import EmbeddingService
from schemas.crud_schema import EmbeddingCreate, EmbeddingUpdate, EmbeddingResponse

router = APIRouter(prefix="/embedding", tags=["Embedding"])


@router.post("/", response_model=EmbeddingResponse)
def create_embedding(
    data: EmbeddingCreate,
    db: Session = Depends(get_db),
    current_user: dict = Depends(require_admin),
):
    try:
        return EmbeddingService.create_embedding(db, data)
    except ValueError as exc:
        raise HTTPException(status_code=400, detail=str(exc))


@router.get("/", response_model=list[EmbeddingResponse])
def get_all_embeddings(
    db: Session = Depends(get_db),
    current_user: dict = Depends(get_current_user),
):
    return EmbeddingService.get_all_embeddings(db)


@router.get("/siswa/{siswa_id}", response_model=list[EmbeddingResponse])
def get_embedding_by_siswa(
    siswa_id: int,
    db: Session = Depends(get_db),
    current_user: dict = Depends(get_current_user),
):
    return EmbeddingService.get_embedding_by_siswa(db, siswa_id)


@router.get("/kelas/{kelas_id}", response_model=list[EmbeddingResponse])
def get_embedding_by_kelas(
    kelas_id: int,
    tahun_pelajaran_id: int | None = None,
    db: Session = Depends(get_db),
    current_user: dict = Depends(get_current_user),
):
    return EmbeddingService.get_embedding_by_kelas(
        db,
        kelas_id,
        tahun_pelajaran_id,
    )


@router.get("/{embedding_id}", response_model=EmbeddingResponse)
def get_embedding(
    embedding_id: int,
    db: Session = Depends(get_db),
    current_user: dict = Depends(get_current_user),
):
    emb = EmbeddingService.get_embedding_by_id(db, embedding_id)
    if not emb:
        raise HTTPException(status_code=404, detail="Embedding tidak ditemukan")
    return emb


@router.put("/{embedding_id}", response_model=EmbeddingResponse)
def update_embedding(
    embedding_id: int,
    data: EmbeddingUpdate,
    db: Session = Depends(get_db),
    current_user: dict = Depends(require_admin),
):
    emb = EmbeddingService.update_embedding(db, embedding_id, data)
    if not emb:
        raise HTTPException(status_code=404, detail="Embedding tidak ditemukan")
    return emb


@router.delete("/{embedding_id}")
def delete_embedding(
    embedding_id: int,
    db: Session = Depends(get_db),
    current_user: dict = Depends(require_admin),
):
    success = EmbeddingService.delete_embedding(db, embedding_id)
    if not success:
        raise HTTPException(status_code=404, detail="Embedding tidak ditemukan")
    return {"message": "Embedding berhasil dihapus"}


@router.delete("/siswa/{siswa_id}")
def delete_embedding_by_siswa(
    siswa_id: int,
    db: Session = Depends(get_db),
    current_user: dict = Depends(require_admin),
):
    success = EmbeddingService.delete_embedding_by_siswa(db, siswa_id)
    if not success:
        raise HTTPException(status_code=404, detail="Embedding tidak ditemukan")
    return {"message": "Embedding siswa berhasil dihapus"}
