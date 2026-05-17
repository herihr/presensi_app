from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import Session

from core.database import get_db
from dependencies.auth import get_current_user, require_admin
from services.kelas_service import KelasService
from schemas.crud_schema import KelasCreate, KelasUpdate, KelasResponse

router = APIRouter(prefix="/kelas", tags=["Kelas"])


@router.post("/", response_model=KelasResponse)
def create_kelas(
    data: KelasCreate,
    db: Session = Depends(get_db),
    current_user: dict = Depends(require_admin),
):
    try:
        return KelasService.create_kelas(db, data)
    except ValueError as exc:
        raise HTTPException(status_code=400, detail=str(exc))
    except IntegrityError:
        raise HTTPException(status_code=400, detail="Nama kelas sudah digunakan")


@router.get("/", response_model=list[KelasResponse])
def get_all_kelas(
    db: Session = Depends(get_db),
    current_user: dict = Depends(get_current_user),
):
    return KelasService.get_all_kelas(db)


@router.get("/{kelas_id}", response_model=KelasResponse)
def get_kelas(
    kelas_id: int,
    db: Session = Depends(get_db),
    current_user: dict = Depends(get_current_user),
):
    kelas = KelasService.get_kelas_by_id(db, kelas_id)
    if not kelas:
        raise HTTPException(status_code=404, detail="Kelas tidak ditemukan")
    return kelas


@router.put("/{kelas_id}", response_model=KelasResponse)
def update_kelas(
    kelas_id: int,
    data: KelasUpdate,
    db: Session = Depends(get_db),
    current_user: dict = Depends(require_admin),
):
    try:
        kelas = KelasService.update_kelas(db, kelas_id, data)
    except ValueError as exc:
        raise HTTPException(status_code=400, detail=str(exc))
    except IntegrityError:
        raise HTTPException(status_code=400, detail="Nama kelas sudah digunakan")
    if not kelas:
        raise HTTPException(status_code=404, detail="Kelas tidak ditemukan")
    return kelas


@router.delete("/{kelas_id}")
def delete_kelas(
    kelas_id: int,
    db: Session = Depends(get_db),
    current_user: dict = Depends(require_admin),
):
    try:
        success = KelasService.delete_kelas(db, kelas_id)
    except IntegrityError:
        db.rollback()
        raise HTTPException(
            status_code=400,
            detail="Kelas tidak bisa dihapus karena masih dipakai oleh data lain",
        )
    if not success:
        raise HTTPException(status_code=404, detail="Kelas tidak ditemukan")
    return {"message": "Kelas berhasil dihapus"}
