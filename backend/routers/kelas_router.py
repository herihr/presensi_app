from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session

from core.database import get_db
from services.kelas_service import KelasService
from schemas.crud_schema import KelasCreate, KelasUpdate, KelasResponse

router = APIRouter(prefix="/kelas", tags=["Kelas"])


@router.post("/", response_model=KelasResponse)
def create_kelas(data: KelasCreate, db: Session = Depends(get_db)):
    return KelasService.create_kelas(db, data)


@router.get("/", response_model=list[KelasResponse])
def get_all_kelas(db: Session = Depends(get_db)):
    return KelasService.get_all_kelas(db)


@router.get("/{kelas_id}", response_model=KelasResponse)
def get_kelas(kelas_id: int, db: Session = Depends(get_db)):
    kelas = KelasService.get_kelas_by_id(db, kelas_id)
    if not kelas:
        raise HTTPException(status_code=404, detail="Kelas tidak ditemukan")
    return kelas


@router.put("/{kelas_id}", response_model=KelasResponse)
def update_kelas(kelas_id: int, data: KelasUpdate, db: Session = Depends(get_db)):
    kelas = KelasService.update_kelas(db, kelas_id, data)
    if not kelas:
        raise HTTPException(status_code=404, detail="Kelas tidak ditemukan")
    return kelas


@router.delete("/{kelas_id}")
def delete_kelas(kelas_id: int, db: Session = Depends(get_db)):
    success = KelasService.delete_kelas(db, kelas_id)
    if not success:
        raise HTTPException(status_code=404, detail="Kelas tidak ditemukan")
    return {"message": "Kelas berhasil dihapus"}