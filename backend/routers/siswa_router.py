from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session

from core.database import get_db
from services.siswa_service import SiswaService
from schemas.crud_schema import SiswaCreate, SiswaUpdate, SiswaResponse

router = APIRouter(prefix="/siswa", tags=["Siswa"])


@router.post("/", response_model=SiswaResponse)
def create_siswa(data: SiswaCreate, db: Session = Depends(get_db)):
    return SiswaService.create_siswa(db, data)


@router.get("/", response_model=list[SiswaResponse])
def get_all_siswa(db: Session = Depends(get_db)):
    return SiswaService.get_all_siswa(db)


@router.get("/{siswa_id}", response_model=SiswaResponse)
def get_siswa(siswa_id: int, db: Session = Depends(get_db)):
    siswa = SiswaService.get_siswa_by_id(db, siswa_id)
    if not siswa:
        raise HTTPException(status_code=404, detail="Siswa tidak ditemukan")
    return siswa


@router.get("/kelas/{kelas_id}", response_model=list[SiswaResponse])
def get_siswa_by_kelas(kelas_id: int, db: Session = Depends(get_db)):
    return SiswaService.get_siswa_by_kelas(db, kelas_id)


@router.put("/{siswa_id}", response_model=SiswaResponse)
def update_siswa(siswa_id: int, data: SiswaUpdate, db: Session = Depends(get_db)):
    siswa = SiswaService.update_siswa(db, siswa_id, data)
    if not siswa:
        raise HTTPException(status_code=404, detail="Siswa tidak ditemukan")
    return siswa


@router.delete("/{siswa_id}")
def delete_siswa(siswa_id: int, db: Session = Depends(get_db)):
    success = SiswaService.delete_siswa(db, siswa_id)
    if not success:
        raise HTTPException(status_code=404, detail="Siswa tidak ditemukan")
    return {"message": "Siswa berhasil dihapus"}