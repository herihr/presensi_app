from sqlalchemy.orm import Session
from models.kelas import Kelas


class KelasService:

    # 🔹 CREATE KELAS
    @staticmethod
    def create_kelas(db: Session, data):
        kelas = Kelas(
            nama_kelas=data.nama_kelas,
            wali_kelas_id=data.wali_kelas_id
        )
        db.add(kelas)
        db.commit()
        db.refresh(kelas)
        return kelas

    # 🔹 GET ALL KELAS
    @staticmethod
    def get_all_kelas(db: Session):
        return db.query(Kelas).all()

    # 🔹 GET KELAS BY ID
    @staticmethod
    def get_kelas_by_id(db: Session, kelas_id: int):
        return db.query(Kelas).filter(Kelas.id == kelas_id).first()

    # 🔹 GET KELAS BY NAMA
    @staticmethod
    def get_kelas_by_nama(db: Session, nama_kelas: str):
        return db.query(Kelas).filter(Kelas.nama_kelas == nama_kelas).first()

    # 🔹 GET KELAS BY WALI KELAS
    @staticmethod
    def get_kelas_by_wali(db: Session, wali_kelas_id: int):
        return db.query(Kelas).filter(Kelas.wali_kelas_id == wali_kelas_id).first()

    # 🔹 UPDATE KELAS
    @staticmethod
    def update_kelas(db: Session, kelas_id: int, data):
        kelas = db.query(Kelas).filter(Kelas.id == kelas_id).first()
        if not kelas:
            return None

        if data.nama_kelas:
            kelas.nama_kelas = data.nama_kelas
        if data.wali_kelas_id:
            kelas.wali_kelas_id = data.wali_kelas_id

        db.commit()
        db.refresh(kelas)
        return kelas

    # 🔹 DELETE KELAS
    @staticmethod
    def delete_kelas(db: Session, kelas_id: int):
        kelas = db.query(Kelas).filter(Kelas.id == kelas_id).first()
        if not kelas:
            return False

        db.delete(kelas)
        db.commit()
        return True