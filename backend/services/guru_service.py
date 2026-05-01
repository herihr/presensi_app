from sqlalchemy.orm import Session
from models.guru import Guru
from core.security import hash_password


class GuruService:

    # 🔹 CREATE GURU
    @staticmethod
    def create_guru(db: Session, data):
        guru = Guru(
            nama=data.nama,
            email=data.email,
            password=hash_password(data.password),
            nip=data.nip
        )
        db.add(guru)
        db.commit()
        db.refresh(guru)
        return guru

    # 🔹 GET ALL GURU
    @staticmethod
    def get_all_guru(db: Session):
        return db.query(Guru).all()

    # 🔹 GET GURU BY ID
    @staticmethod
    def get_guru_by_id(db: Session, guru_id: int):
        return db.query(Guru).filter(Guru.id == guru_id).first()

    # 🔹 GET GURU BY EMAIL
    @staticmethod
    def get_guru_by_email(db: Session, email: str):
        return db.query(Guru).filter(Guru.email == email).first()

    # 🔹 GET GURU BY NIP
    @staticmethod
    def get_guru_by_nip(db: Session, nip: str):
        return db.query(Guru).filter(Guru.nip == nip).first()

    # 🔹 UPDATE GURU
    @staticmethod
    def update_guru(db: Session, guru_id: int, data):
        guru = db.query(Guru).filter(Guru.id == guru_id).first()
        if not guru:
            return None

        if data.nama:
            guru.nama = data.nama
        if data.email:
            guru.email = data.email
        if data.nip:
            guru.nip = data.nip
        if data.password:
            guru.password = hash_password(data.password)

        db.commit()
        db.refresh(guru)
        return guru

    # 🔹 DELETE GURU
    @staticmethod
    def delete_guru(db: Session, guru_id: int):
        guru = db.query(Guru).filter(Guru.id == guru_id).first()
        if not guru:
            return False

        db.delete(guru)
        db.commit()
        return True