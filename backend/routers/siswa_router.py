from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import Session

from core.database import get_db
from dependencies.auth import get_current_user, require_admin
from services.siswa_service import SiswaService
from schemas.crud_schema import SiswaCreate, SiswaUpdate, SiswaResponse

router = APIRouter(prefix="/siswa", tags=["Siswa"])


@router.post("/", response_model=SiswaResponse)
def create_siswa(
    data: SiswaCreate,
    db: Session = Depends(get_db),
    current_user: dict = Depends(require_admin),
):
    try:
        return SiswaService.create_siswa(db, data)
    except ValueError as exc:
        raise HTTPException(status_code=400, detail=str(exc))
    except IntegrityError:
        raise HTTPException(status_code=400, detail="NIS siswa sudah digunakan")


@router.get("/", response_model=list[SiswaResponse])
def get_all_siswa(
    db: Session = Depends(get_db),
    current_user: dict = Depends(get_current_user),
):
    return SiswaService.get_all_siswa(db)


@router.get("/kelas/{kelas_id}", response_model=list[SiswaResponse])
def get_siswa_by_kelas(
    kelas_id: int,
    db: Session = Depends(get_db),
    current_user: dict = Depends(get_current_user),
):
    return SiswaService.get_siswa_by_kelas(db, kelas_id)


@router.get("/{siswa_id}", response_model=SiswaResponse)
def get_siswa(
    siswa_id: int,
    db: Session = Depends(get_db),
    current_user: dict = Depends(get_current_user),
):
    siswa = SiswaService.get_siswa_by_id(db, siswa_id)
    if not siswa:
        raise HTTPException(status_code=404, detail="Siswa tidak ditemukan")
    return siswa


@router.put("/{siswa_id}", response_model=SiswaResponse)
def update_siswa(
    siswa_id: int,
    data: SiswaUpdate,
    db: Session = Depends(get_db),
    current_user: dict = Depends(require_admin),
):
    try:
        siswa = SiswaService.update_siswa(db, siswa_id, data)
    except ValueError as exc:
        raise HTTPException(status_code=400, detail=str(exc))
    except IntegrityError:
        raise HTTPException(status_code=400, detail="NIS siswa sudah digunakan")
    if not siswa:
        raise HTTPException(status_code=404, detail="Siswa tidak ditemukan")
    return siswa


@router.delete("/{siswa_id}")
def delete_siswa(
    siswa_id: int,
    db: Session = Depends(get_db),
    current_user: dict = Depends(require_admin),
):
    try:
        success = SiswaService.delete_siswa(db, siswa_id)
    except IntegrityError:
        raise HTTPException(
            status_code=400,
            detail="Siswa tidak bisa dihapus karena masih memiliki data presensi atau embedding",
        )
    if not success:
        raise HTTPException(status_code=404, detail="Siswa tidak ditemukan")
    return {"message": "Siswa berhasil dihapus"}
