from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import Session

from core.database import get_db
from dependencies.auth import get_current_user, require_admin
from schemas.crud_schema import (
    TahunPelajaranCreate,
    TahunPelajaranResponse,
    TahunPelajaranUpdate,
)
from services.tahun_pelajaran_service import TahunPelajaranService

router = APIRouter(prefix="/tahun-pelajaran", tags=["Tahun Pelajaran"])


@router.post("/", response_model=TahunPelajaranResponse)
def create_tahun_pelajaran(
    data: TahunPelajaranCreate,
    db: Session = Depends(get_db),
    current_user: dict = Depends(require_admin),
):
    try:
        return TahunPelajaranService.create(db, data)
    except IntegrityError:
        raise HTTPException(status_code=400, detail="Tahun pelajaran sudah ada")


@router.get("/", response_model=list[TahunPelajaranResponse])
def get_all_tahun_pelajaran(
    db: Session = Depends(get_db),
    current_user: dict = Depends(get_current_user),
):
    return TahunPelajaranService.get_all(db)


@router.get("/aktif", response_model=TahunPelajaranResponse)
def get_active_tahun_pelajaran(
    db: Session = Depends(get_db),
    current_user: dict = Depends(get_current_user),
):
    return TahunPelajaranService.get_active(db)


@router.put("/{tahun_id}", response_model=TahunPelajaranResponse)
def update_tahun_pelajaran(
    tahun_id: int,
    data: TahunPelajaranUpdate,
    db: Session = Depends(get_db),
    current_user: dict = Depends(require_admin),
):
    try:
        item = TahunPelajaranService.update(db, tahun_id, data)
    except IntegrityError:
        raise HTTPException(status_code=400, detail="Tahun pelajaran sudah ada")
    if not item:
        raise HTTPException(status_code=404, detail="Tahun pelajaran tidak ditemukan")
    return item


@router.put("/{tahun_id}/aktif", response_model=TahunPelajaranResponse)
def set_active_tahun_pelajaran(
    tahun_id: int,
    db: Session = Depends(get_db),
    current_user: dict = Depends(require_admin),
):
    item = TahunPelajaranService.set_active(db, tahun_id)
    if not item:
        raise HTTPException(status_code=404, detail="Tahun pelajaran tidak ditemukan")
    return item
