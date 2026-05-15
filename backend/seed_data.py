from core.database import SessionLocal
from core.security import hash_password

# 🔥 IMPORT SEMUA MODEL (penting untuk relationship)
from models import admin, guru, siswa, kelas, mata_pelajaran, jadwal, presensi, embedding
from models import guru_mapel

from models.admin import Admin
from models.guru import Guru

db = SessionLocal()

def seed_admin():
    existing = db.query(Admin).filter(Admin.email == "admin@gmail.com").first()

    if not existing:
        admin = Admin(
            nama="Admin",
            email="admin@gmail.com",
            password=hash_password("123456")
        )
        db.add(admin)
        print("✅ Admin dibuat")
    else:
        print("⚠️ Admin sudah ada")


def seed_guru():
    existing = db.query(Guru).filter(Guru.email == "guru@gmail.com").first()

    if not existing:
        guru = Guru(
            nama="Guru 1",
            email="guru@gmail.com",
            password=hash_password("123456"),
            nip="123456789"
        )
        db.add(guru)
        print("✅ Guru dibuat")
    else:
        print("⚠️ Guru sudah ada")


def run_seed():
    try:
        seed_admin()
        seed_guru()
        db.commit()
        print("🔥 Seed selesai tanpa error")
    except Exception as e:
        db.rollback()
        print("❌ ERROR:", e)
    finally:
        db.close()


if __name__ == "__main__":
    run_seed()
