import os
import secrets
import smtplib
from datetime import datetime, timedelta
from email.message import EmailMessage

from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy import func
from sqlalchemy.orm import Session

from core.database import get_db
from core.security import verify_password, create_access_token, hash_password

from models.guru import Guru
from models.admin import Admin
from models.kelas import Kelas
from models.guru_mapel import GuruMapel
from models.password_reset import PasswordResetCode

from schemas.auth_schema import ForgotPasswordRequest, LoginRequest, ResetPasswordRequest

router = APIRouter()
RESET_CODE_TTL_MINUTES = 10
RESET_CODE_MAX_ATTEMPTS = 5


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
                "jenis_kelamin": guru.jenis_kelamin,
                "email": guru.email,
                "foto_url": guru.foto_url,
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
                "email": admin.email,
                "foto_url": admin.foto_url,
                "role": "admin",
                "is_wali": False,
                "is_mapel": False
            }
        }

    # =====================
    # ❌ GAGAL LOGIN
    # =====================
    raise HTTPException(status_code=401, detail="Login gagal")


@router.post("/forgot-password")
def forgot_password(data: ForgotPasswordRequest, db: Session = Depends(get_db)):
    account, role = _find_account_for_reset(db, data.email, data.role)
    if account is None or role is None:
        print(
            "WARNING: forgot password account not found "
            f"email={data.email} role={data.role}"
        )
        raise HTTPException(status_code=404, detail="Email tidak ditemukan")

    code = f"{secrets.randbelow(1_000_000):06d}"
    now = datetime.utcnow()
    email = account.email.strip().lower()

    db.query(PasswordResetCode).filter(
        PasswordResetCode.email == email,
        PasswordResetCode.role == role,
        PasswordResetCode.used == False,  # noqa: E712
    ).update({"used": True})

    reset_code = PasswordResetCode(
        email=email,
        role=role,
        code_hash=hash_password(code),
        expires_at=now + timedelta(minutes=RESET_CODE_TTL_MINUTES),
        attempts=0,
        used=False,
        created_at=now,
    )
    db.add(reset_code)
    db.commit()

    email_sent = _send_reset_email(account.email, account.nama, code)
    return {
        "message": "Kode reset password sudah dibuat",
        "email_sent": email_sent,
        "expires_in_minutes": RESET_CODE_TTL_MINUTES,
    }


@router.post("/reset-password")
def reset_password(data: ResetPasswordRequest, db: Session = Depends(get_db)):
    if len(data.new_password.strip()) < 6:
        raise HTTPException(status_code=400, detail="Password baru minimal 6 karakter")

    account, role = _find_account_for_reset(db, data.email, data.role)
    if account is None or role is None:
        raise HTTPException(status_code=404, detail="Email tidak ditemukan")

    reset_code = (
        db.query(PasswordResetCode)
        .filter(
            PasswordResetCode.email == account.email.strip().lower(),
            PasswordResetCode.role == role,
            PasswordResetCode.used == False,  # noqa: E712
        )
        .order_by(PasswordResetCode.created_at.desc())
        .first()
    )

    if reset_code is None:
        raise HTTPException(status_code=400, detail="Kode reset tidak ditemukan")

    if reset_code.expires_at < datetime.utcnow():
        reset_code.used = True
        db.commit()
        raise HTTPException(status_code=400, detail="Kode reset sudah kedaluwarsa")

    if reset_code.attempts >= RESET_CODE_MAX_ATTEMPTS:
        reset_code.used = True
        db.commit()
        raise HTTPException(status_code=400, detail="Kode reset sudah terlalu sering dicoba")

    if not verify_password(data.code.strip(), reset_code.code_hash):
        reset_code.attempts += 1
        db.commit()
        raise HTTPException(status_code=400, detail="Kode reset tidak valid")

    account.password = hash_password(data.new_password)
    reset_code.used = True
    db.commit()

    return {"message": "Password berhasil direset"}


def _find_account_for_reset(db: Session, email: str, role: str | None):
    normalized_email = email.strip().lower()
    normalized_role = role.strip().lower() if role else None

    if normalized_role == "admin":
        admin = (
            db.query(Admin)
            .filter(func.lower(func.trim(Admin.email)) == normalized_email)
            .first()
        )
        return admin, "admin" if admin else None

    if normalized_role == "guru":
        guru = (
            db.query(Guru)
            .filter(func.lower(func.trim(Guru.email)) == normalized_email)
            .first()
        )
        return guru, "guru" if guru else None

    guru = (
        db.query(Guru)
        .filter(func.lower(func.trim(Guru.email)) == normalized_email)
        .first()
    )
    if guru:
        return guru, "guru"

    admin = (
        db.query(Admin)
        .filter(func.lower(func.trim(Admin.email)) == normalized_email)
        .first()
    )
    if admin:
        return admin, "admin"

    return None, None


def _send_reset_email(email: str, name: str, code: str) -> bool:
    smtp_host = os.getenv("SMTP_HOST")
    smtp_port = int(os.getenv("SMTP_PORT", "587"))
    smtp_user = os.getenv("SMTP_USER")
    smtp_password = os.getenv("SMTP_PASSWORD")
    smtp_from = os.getenv("SMTP_FROM") or smtp_user
    smtp_tls = os.getenv("SMTP_TLS", "true").lower() != "false"

    if not smtp_host or not smtp_user or not smtp_password or not smtp_from:
        print(
            "WARNING: SMTP belum dikonfigurasi. "
            f"Kode reset untuk {email}: {code}"
        )
        return False

    message = EmailMessage()
    message["Subject"] = "Kode Reset Password PresenSatu"
    message["From"] = smtp_from
    message["To"] = email
    message.set_content(
        f"Halo {name},\n\n"
        f"Kode reset password PresenSatu kamu adalah: {code}\n\n"
        f"Kode ini berlaku selama {RESET_CODE_TTL_MINUTES} menit. "
        "Jika kamu tidak meminta reset password, abaikan email ini.\n\n"
        "PresenSatu"
    )

    try:
        with smtplib.SMTP(smtp_host, smtp_port, timeout=20) as server:
            if smtp_tls:
                server.starttls()
            server.login(smtp_user, smtp_password)
            server.send_message(message)
        return True
    except Exception as exc:
        print(f"WARNING: gagal mengirim email reset password ke {email}: {exc}")
        return False
