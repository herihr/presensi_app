from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session

from core.database import get_db
from dependencies.auth import get_current_user

from services.admin_service import AdminService
from schemas.admin_schema import GuruCreate, GuruUpdate, GuruResponse

router = APIRouter()


# 🔐 (opsional) cek admin role nanti bisa ditambahkan


# 🔹 CREATE GURU
@router.post("/guru", response_model=GuruResponse)
def create_guru(
    data: GuruCreate,
    db: Session = Depends(get_db)
):
    return AdminService.create_guru(db, data)


# 🔹 GET ALL GURU
@router.get("/guru", response_model=list[GuruResponse])
def get_all_guru(db: Session = Depends(get_db)):
    return AdminService.get_all_guru(db)


# 🔹 GET GURU BY ID
@router.get("/guru/{guru_id}", response_model=GuruResponse)
def get_guru(guru_id: int, db: Session = Depends(get_db)):
    guru = AdminService.get_guru_by_id(db, guru_id)

    if not guru:
        raise HTTPException(status_code=404, detail="Guru tidak ditemukan")

    return guru


# 🔹 UPDATE GURU
@router.put("/guru/{guru_id}", response_model=GuruResponse)
def update_guru(
    guru_id: int,
    data: GuruUpdate,
    db: Session = Depends(get_db)
):
    guru = AdminService.update_guru(db, guru_id, data)

    if not guru:
        raise HTTPException(status_code=404, detail="Guru tidak ditemukan")

    return guru


# 🔹 DELETE GURU
@router.delete("/guru/{guru_id}")
def delete_guru(guru_id: int, db: Session = Depends(get_db)):
    success = AdminService.delete_guru(db, guru_id)

    if not success:
        raise HTTPException(status_code=404, detail="Guru tidak ditemukan")

    return {"message": "Guru berhasil dihapus"}