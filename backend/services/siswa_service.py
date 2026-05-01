from sqlalchemy.orm import Session
from models.siswa import Siswa
from core.security import hash_password


class SiswaService:

    # 🔹 CREATE SISWA
    @staticmethod
    def create_siswa(db: Session, data):
        siswa = Siswa(
            nama=data.nama,
            nis=data.nis,
            kelas_id=data.kelas_id
        )
        db.add(siswa)
        db.commit()
        db.refresh(siswa)
        return siswa

    # 🔹 GET ALL SISWA
    @staticmethod
    def get_all_siswa(db: Session):
        return db.query(Siswa).all()

    # 🔹 GET SISWA BY ID
    @staticmethod
    def get_siswa_by_id(db: Session, siswa_id: int):
        return db.query(Siswa).filter(Siswa.id == siswa_id).first()

    # 🔹 GET SISWA BY NIS
    @staticmethod
    def get_siswa_by_nis(db: Session, nis: str):
        return db.query(Siswa).filter(Siswa.nis == nis).first()

    # 🔹 GET SISWA BY KELAS
    @staticmethod
    def get_siswa_by_kelas(db: Session, kelas_id: int):
        return db.query(Siswa).filter(Siswa.kelas_id == kelas_id).all()

    # 🔹 UPDATE SISWA
    @staticmethod
    def update_siswa(db: Session, siswa_id: int, data):
        siswa = db.query(Siswa).filter(Siswa.id == siswa_id).first()
        if not siswa:
            return None

        if data.nama:
            siswa.nama = data.nama
        if data.nis:
            siswa.nis = data.nis
        if data.kelas_id:
            siswa.kelas_id = data.kelas_id

        db.commit()
        db.refresh(siswa)
        return siswa

    # 🔹 DELETE SISWA
    @staticmethod
    def delete_siswa(db: Session, siswa_id: int):
        siswa = db.query(Siswa).filter(Siswa.id == siswa_id).first()
        if not siswa:
            return False

        db.delete(siswa)
        db.commit()
        return True