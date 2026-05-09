from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session

from core.database import get_db
from dependencies.auth import require_admin
from schemas.crud_schema import (
    AdminCreate, AdminUpdate, AdminResponse
)
from services.admin_service import AdminService

router = APIRouter(
    prefix="/admin",
    tags=["Admin"],
    dependencies=[Depends(require_admin)],
)


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
