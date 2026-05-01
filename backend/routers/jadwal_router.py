from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session

from core.database import get_db
from services.jadwal_service import JadwalService
from schemas.crud_schema import JadwalCreate, JadwalUpdate, JadwalResponse

router = APIRouter(prefix="/jadwal", tags=["Jadwal"])


@router.post("/", response_model=JadwalResponse)
def create_jadwal(data: JadwalCreate, db: Session = Depends(get_db)):
    return JadwalService.create_jadwal(db, data)


@router.get("/", response_model=list[JadwalResponse])
def get_all_jadwal(db: Session = Depends(get_db)):
    return JadwalService.get_all_jadwal(db)


@router.get("/{jadwal_id}", response_model=JadwalResponse)
def get_jadwal(jadwal_id: int, db: Session = Depends(get_db)):
    jadwal = JadwalService.get_jadwal_by_id(db, jadwal_id)
    if not jadwal:
        raise HTTPException(status_code=404, detail="Jadwal tidak ditemukan")
    return jadwal


@router.get("/kelas/{kelas_id}", response_model=list[JadwalResponse])
def get_jadwal_by_kelas(kelas_id: int, db: Session = Depends(get_db)):
    return JadwalService.get_jadwal_by_kelas(db, kelas_id)


@router.get("/guru/{guru_id}", response_model=list[JadwalResponse])
def get_jadwal_by_guru(guru_id: int, db: Session = Depends(get_db)):
    return JadwalService.get_jadwal_by_guru(db, guru_id)


@router.get("/mapel/{mapel_id}", response_model=list[JadwalResponse])
def get_jadwal_by_mapel(mapel_id: int, db: Session = Depends(get_db)):
    return JadwalService.get_jadwal_by_mapel(db, mapel_id)


@router.get("/hari/{kelas_id}/{hari}", response_model=list[JadwalResponse])
def get_jadwal_by_hari(kelas_id: int, hari: str, db: Session = Depends(get_db)):
    return JadwalService.get_jadwal_by_hari(db, kelas_id, hari)


@router.put("/{jadwal_id}", response_model=JadwalResponse)
def update_jadwal(jadwal_id: int, data: JadwalUpdate, db: Session = Depends(get_db)):
    jadwal = JadwalService.update_jadwal(db, jadwal_id, data)
    if not jadwal:
        raise HTTPException(status_code=404, detail="Jadwal tidak ditemukan")
    return jadwal


@router.delete("/{jadwal_id}")
def delete_jadwal(jadwal_id: int, db: Session = Depends(get_db)):
    success = JadwalService.delete_jadwal(db, jadwal_id)
    if not success:
        raise HTTPException(status_code=404, detail="Jadwal tidak ditemukan")
    return {"message": "Jadwal berhasil dihapus"}