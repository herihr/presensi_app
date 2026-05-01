from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session

from core.database import get_db
from services.guru_service import GuruService
from schemas.crud_schema import GuruCreate, GuruUpdate, GuruResponse

router = APIRouter(prefix="/guru", tags=["Guru"])


@router.post("/", response_model=GuruResponse)
def create_guru(data: GuruCreate, db: Session = Depends(get_db)):
    return GuruService.create_guru(db, data)


@router.get("/", response_model=list[GuruResponse])
def get_all_guru(db: Session = Depends(get_db)):
    return GuruService.get_all_guru(db)


@router.get("/{guru_id}", response_model=GuruResponse)
def get_guru(guru_id: int, db: Session = Depends(get_db)):
    guru = GuruService.get_guru_by_id(db, guru_id)
    if not guru:
        raise HTTPException(status_code=404, detail="Guru tidak ditemukan")
    return guru


@router.put("/{guru_id}", response_model=GuruResponse)
def update_guru(guru_id: int, data: GuruUpdate, db: Session = Depends(get_db)):
    guru = GuruService.update_guru(db, guru_id, data)
    if not guru:
        raise HTTPException(status_code=404, detail="Guru tidak ditemukan")
    return guru


@router.delete("/{guru_id}")
def delete_guru(guru_id: int, db: Session = Depends(get_db)):
    success = GuruService.delete_guru(db, guru_id)
    if not success:
        raise HTTPException(status_code=404, detail="Guru tidak ditemukan")
    return {"message": "Guru berhasil dihapus"}