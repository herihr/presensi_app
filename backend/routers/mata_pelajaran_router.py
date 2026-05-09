from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import Session

from core.database import get_db
from dependencies.auth import get_current_user, require_admin
from services.mata_pelajaran_service import MataPelajaranService
from schemas.crud_schema import (
    MataPelajaranCreate, 
    MataPelajaranUpdate, 
    MataPelajaranResponse
)

router = APIRouter(prefix="/mata-pelajaran", tags=["Mata Pelajaran"])


@router.post("/", response_model=MataPelajaranResponse)
def create_mata_pelajaran(
    data: MataPelajaranCreate,
    db: Session = Depends(get_db),
    current_user: dict = Depends(require_admin),
):
    try:
        return MataPelajaranService.create_mata_pelajaran(db, data)
    except ValueError as exc:
        raise HTTPException(status_code=400, detail=str(exc))
    except IntegrityError:
        raise HTTPException(status_code=400, detail="Nama mata pelajaran sudah digunakan")


@router.get("/", response_model=list[MataPelajaranResponse])
def get_all_mata_pelajaran(
    db: Session = Depends(get_db),
    current_user: dict = Depends(get_current_user),
):
    return MataPelajaranService.get_all_mata_pelajaran(db)


@router.get("/{mapel_id}", response_model=MataPelajaranResponse)
def get_mata_pelajaran(
    mapel_id: int,
    db: Session = Depends(get_db),
    current_user: dict = Depends(get_current_user),
):
    mapel = MataPelajaranService.get_mata_pelajaran_by_id(db, mapel_id)
    if not mapel:
        raise HTTPException(status_code=404, detail="Mata pelajaran tidak ditemukan")
    return mapel


@router.put("/{mapel_id}", response_model=MataPelajaranResponse)
def update_mata_pelajaran(
    mapel_id: int,
    data: MataPelajaranUpdate,
    db: Session = Depends(get_db),
    current_user: dict = Depends(require_admin),
):
    try:
        mapel = MataPelajaranService.update_mata_pelajaran(db, mapel_id, data)
    except ValueError as exc:
        raise HTTPException(status_code=400, detail=str(exc))
    except IntegrityError:
        raise HTTPException(status_code=400, detail="Nama mata pelajaran sudah digunakan")
    if not mapel:
        raise HTTPException(status_code=404, detail="Mata pelajaran tidak ditemukan")
    return mapel


@router.delete("/{mapel_id}")
def delete_mata_pelajaran(
    mapel_id: int,
    db: Session = Depends(get_db),
    current_user: dict = Depends(require_admin),
):
    success = MataPelajaranService.delete_mata_pelajaran(db, mapel_id)
    if not success:
        raise HTTPException(status_code=404, detail="Mata pelajaran tidak ditemukan")
    return {"message": "Mata pelajaran berhasil dihapus"}
