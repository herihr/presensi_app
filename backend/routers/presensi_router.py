from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import Session

from core.database import get_db
from dependencies.auth import get_current_user, require_admin
from services.presensi_service import PresensiService
from schemas.crud_schema import PresensiCreate, PresensiUpdate, PresensiResponse

router = APIRouter(prefix="/presensi", tags=["Presensi"])


@router.post("/", response_model=PresensiResponse)
def create_presensi(
    data: PresensiCreate,
    db: Session = Depends(get_db),
    current_user: dict = Depends(get_current_user),
):
    try:
        return PresensiService.create_presensi(db, data)
    except ValueError as exc:
        raise HTTPException(status_code=400, detail=str(exc)) from exc
    except IntegrityError as exc:
        raise HTTPException(
            status_code=400,
            detail="Presensi siswa pada jadwal dan tanggal ini sudah ada",
        ) from exc


@router.get("/", response_model=list[PresensiResponse])
def get_all_presensi(
    db: Session = Depends(get_db),
    current_user: dict = Depends(get_current_user),
):
    return PresensiService.get_all_presensi(db)


@router.get("/siswa/{siswa_id}", response_model=list[PresensiResponse])
def get_presensi_by_siswa(
    siswa_id: int,
    db: Session = Depends(get_db),
    current_user: dict = Depends(get_current_user),
):
    return PresensiService.get_presensi_by_siswa(db, siswa_id)


@router.get("/jadwal/{jadwal_id}", response_model=list[PresensiResponse])
def get_presensi_by_jadwal(
    jadwal_id: int,
    db: Session = Depends(get_db),
    current_user: dict = Depends(get_current_user),
):
    return PresensiService.get_presensi_by_jadwal(db, jadwal_id)


@router.get("/guru/{guru_id}", response_model=list[PresensiResponse])
def get_presensi_by_guru(
    guru_id: int,
    db: Session = Depends(get_db),
    current_user: dict = Depends(get_current_user),
):
    return PresensiService.get_presensi_by_guru(db, guru_id)


@router.get("/tanggal/{tanggal}", response_model=list[PresensiResponse])
def get_presensi_by_tanggal(
    tanggal: str,
    db: Session = Depends(get_db),
    current_user: dict = Depends(get_current_user),
):
    return PresensiService.get_presensi_by_tanggal(db, tanggal)


@router.get("/{presensi_id}", response_model=PresensiResponse)
def get_presensi(
    presensi_id: int,
    db: Session = Depends(get_db),
    current_user: dict = Depends(get_current_user),
):
    presensi = PresensiService.get_presensi_by_id(db, presensi_id)
    if not presensi:
        raise HTTPException(status_code=404, detail="Presensi tidak ditemukan")
    return presensi


@router.put("/{presensi_id}", response_model=PresensiResponse)
def update_presensi(
    presensi_id: int,
    data: PresensiUpdate,
    db: Session = Depends(get_db),
    current_user: dict = Depends(require_admin),
):
    try:
        presensi = PresensiService.update_presensi(db, presensi_id, data)
    except ValueError as exc:
        raise HTTPException(status_code=400, detail=str(exc)) from exc
    except IntegrityError as exc:
        raise HTTPException(
            status_code=400,
            detail="Presensi siswa pada jadwal dan tanggal ini sudah ada",
        ) from exc
    if not presensi:
        raise HTTPException(status_code=404, detail="Presensi tidak ditemukan")
    return presensi


@router.delete("/{presensi_id}")
def delete_presensi(
    presensi_id: int,
    db: Session = Depends(get_db),
    current_user: dict = Depends(require_admin),
):
    success = PresensiService.delete_presensi(db, presensi_id)
    if not success:
        raise HTTPException(status_code=404, detail="Presensi tidak ditemukan")
    return {"message": "Presensi berhasil dihapus"}
