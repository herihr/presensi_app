from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session

from core.database import get_db
from schemas.presensi_schema import PresensiCreate
from services.presensi_service import PresensiService

router = APIRouter()


@router.post("/")
def create_presensi(data: PresensiCreate, db: Session = Depends(get_db)):
    return PresensiService.create_presensi(
        db,
        data.siswa_id,
        data.jadwal_id
    )