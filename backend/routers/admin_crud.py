from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session

from core.database import get_db
from services.guru_service import GuruService
from schemas.crud_schema import (
    GuruCreate, GuruUpdate, GuruResponse,
    AdminCreate, AdminUpdate, AdminResponse
)
from services.admin_service import AdminService

router = APIRouter(prefix="/admin", tags=["Admin"])


# ============ ADMIN CRUD ============

@router.post("/", response_model=AdminResponse)
def create_admin(data: AdminCreate, db: Session = Depends(get_db)):
    return AdminService.create_admin(db, data)


@router.get("/", response_model=list[AdminResponse])
def get_all_admin(db: Session = Depends(get_db)):
    return AdminService.get_all_admin(db)


@router.get("/{admin_id}", response_model=AdminResponse)
def get_admin(admin_id: int, db: Session = Depends(get_db)):
    admin = AdminService.get_admin_by_id(db, admin_id)
    if not admin:
        raise HTTPException(status_code=404, detail="Admin tidak ditemukan")
    return admin


@router.put("/{admin_id}", response_model=AdminResponse)
def update_admin(admin_id: int, data: AdminUpdate, db: Session = Depends(get_db)):
    admin = AdminService.update_admin(db, admin_id, data)
    if not admin:
        raise HTTPException(status_code=404, detail="Admin tidak ditemukan")
    return admin


@router.delete("/{admin_id}")
def delete_admin(admin_id: int, db: Session = Depends(get_db)):
    success = AdminService.delete_admin(db, admin_id)
    if not success:
        raise HTTPException(status_code=404, detail="Admin tidak ditemukan")
    return {"message": "Admin berhasil dihapus"}


# ============ GURU CRUD ============

@router.post("/guru", response_model=GuruResponse)
def create_guru(data: GuruCreate, db: Session = Depends(get_db)):
    return AdminService.create_guru(db, data)


@router.get("/guru", response_model=list[GuruResponse])
def get_all_guru(db: Session = Depends(get_db)):
    return AdminService.get_all_guru(db)


@router.get("/guru/{guru_id}", response_model=GuruResponse)
def get_guru(guru_id: int, db: Session = Depends(get_db)):
    guru = AdminService.get_guru_by_id(db, guru_id)
    if not guru:
        raise HTTPException(status_code=404, detail="Guru tidak ditemukan")
    return guru


@router.put("/guru/{guru_id}", response_model=GuruResponse)
def update_guru(guru_id: int, data: GuruUpdate, db: Session = Depends(get_db)):
    guru = AdminService.update_guru(db, guru_id, data)
    if not guru:
        raise HTTPException(status_code=404, detail="Guru tidak ditemukan")
    return guru


@router.delete("/guru/{guru_id}")
def delete_guru(guru_id: int, db: Session = Depends(get_db)):
    success = AdminService.delete_guru(db, guru_id)
    if not success:
        raise HTTPException(status_code=404, detail="Guru tidak ditemukan")
    return {"message": "Guru berhasil dihapus"}