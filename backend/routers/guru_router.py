from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import Session

from core.database import get_db
from dependencies.auth import get_current_user, require_admin, require_guru
from services.guru_service import GuruService
from schemas.crud_schema import GuruCreate, GuruUpdate, GuruProfileUpdate, GuruResponse

router = APIRouter(prefix="/guru", tags=["Guru"])


@router.post("/", response_model=GuruResponse)
def create_guru(
    data: GuruCreate,
    db: Session = Depends(get_db),
    current_user: dict = Depends(require_admin),
):
    try:
        return GuruService.create_guru(db, data)
    except ValueError as exc:
        raise HTTPException(status_code=400, detail=str(exc))
    except IntegrityError:
        raise HTTPException(status_code=400, detail="Email atau NIP guru sudah digunakan")


@router.get("/", response_model=list[GuruResponse])
def get_all_guru(
    db: Session = Depends(get_db),
    current_user: dict = Depends(get_current_user),
):
    return GuruService.get_all_guru(db)


@router.get("/mapel/{mapel_id}", response_model=list[GuruResponse])
def get_guru_by_mapel(
    mapel_id: int,
    db: Session = Depends(get_db),
    current_user: dict = Depends(get_current_user),
):
    return GuruService.get_guru_by_mapel(db, mapel_id)


@router.get("/me", response_model=GuruResponse)
def get_my_guru_profile(
    db: Session = Depends(get_db),
    current_user: dict = Depends(require_guru),
):
    guru = GuruService.get_guru_by_id(db, current_user["id"])
    if not guru:
        raise HTTPException(status_code=404, detail="Guru tidak ditemukan")
    return guru


@router.put("/me", response_model=GuruResponse)
def update_my_guru_profile(
    data: GuruProfileUpdate,
    db: Session = Depends(get_db),
    current_user: dict = Depends(require_guru),
):
    try:
        guru = GuruService.update_guru(db, current_user["id"], data)
    except ValueError as exc:
        raise HTTPException(status_code=400, detail=str(exc))
    except IntegrityError:
        raise HTTPException(status_code=400, detail="Email atau NIP guru sudah digunakan")
    if not guru:
        raise HTTPException(status_code=404, detail="Guru tidak ditemukan")
    return guru


@router.get("/{guru_id}", response_model=GuruResponse)
def get_guru(
    guru_id: int,
    db: Session = Depends(get_db),
    current_user: dict = Depends(get_current_user),
):
    guru = GuruService.get_guru_by_id(db, guru_id)
    if not guru:
        raise HTTPException(status_code=404, detail="Guru tidak ditemukan")
    return guru


@router.put("/{guru_id}", response_model=GuruResponse)
def update_guru(
    guru_id: int,
    data: GuruUpdate,
    db: Session = Depends(get_db),
    current_user: dict = Depends(require_admin),
):
    try:
        guru = GuruService.update_guru(db, guru_id, data)
    except ValueError as exc:
        raise HTTPException(status_code=400, detail=str(exc))
    except IntegrityError:
        raise HTTPException(status_code=400, detail="Email atau NIP guru sudah digunakan")
    if not guru:
        raise HTTPException(status_code=404, detail="Guru tidak ditemukan")
    return guru


@router.delete("/{guru_id}")
def delete_guru(
    guru_id: int,
    db: Session = Depends(get_db),
    current_user: dict = Depends(require_admin),
):
    try:
        success = GuruService.delete_guru(db, guru_id)
    except IntegrityError:
        raise HTTPException(
            status_code=400,
            detail="Guru tidak bisa dihapus karena masih dipakai pada jadwal atau presensi",
        )
    if not success:
        raise HTTPException(status_code=404, detail="Guru tidak ditemukan")
    return {"message": "Guru berhasil dihapus"}
