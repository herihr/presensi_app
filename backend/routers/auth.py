from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session

from core.database import get_db
from core.security import verify_password, create_access_token

from models.guru import Guru
from models.admin import Admin
from models.kelas import Kelas
from models.guru_mapel import GuruMapel

from schemas.auth_schema import LoginRequest

router = APIRouter()


@router.post("/login")
def login(data: LoginRequest, db: Session = Depends(get_db)):

    # =====================
    # 🔍 CEK GURU
    # =====================
    guru = db.query(Guru).filter(Guru.email == data.email).first()

    if guru and verify_password(data.password, guru.password):

        # 🔎 cek apakah wali kelas
        is_wali = db.query(Kelas).filter(
            Kelas.wali_kelas_id == guru.id
        ).first() is not None

        # 🔎 cek apakah guru mapel
        is_mapel = db.query(GuruMapel).filter(
            GuruMapel.guru_id == guru.id
        ).first() is not None

        token = create_access_token({
            "sub": str(guru.id),
            "role": "guru"
        })

        return {
            "access_token": token,
            "token_type": "bearer",
            "user": {
                "id": guru.id,
                "nama": guru.nama,
                "role": "guru",
                "is_wali": is_wali,
                "is_mapel": is_mapel
            }
        }

    # =====================
    # 🔍 CEK ADMIN
    # =====================
    admin = db.query(Admin).filter(Admin.email == data.email).first()

    if admin and verify_password(data.password, admin.password):

        token = create_access_token({
            "sub": str(admin.id),
            "role": "admin"
        })

        return {
            "access_token": token,
            "token_type": "bearer",
            "user": {
                "id": admin.id,
                "nama": admin.nama,
                "role": "admin",
                "is_wali": False,
                "is_mapel": False
            }
        }

    # =====================
    # ❌ GAGAL LOGIN
    # =====================
    raise HTTPException(status_code=401, detail="Login gagal")