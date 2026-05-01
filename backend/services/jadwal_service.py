from sqlalchemy.orm import Session
from models.jadwal import Jadwal


class JadwalService:

    # 🔹 CREATE JADWAL
    @staticmethod
    def create_jadwal(db: Session, data):
        jadwal = Jadwal(
            kelas_id=data.kelas_id,
            mapel_id=data.mapel_id,
            guru_id=data.guru_id,
            hari=data.hari,
            jam_mulai=data.jam_mulai,
            jam_selesai=data.jam_selesai
        )
        db.add(jadwal)
        db.commit()
        db.refresh(jadwal)
        return jadwal

    # 🔹 GET ALL JADWAL
    @staticmethod
    def get_all_jadwal(db: Session):
        return db.query(Jadwal).all()

    # 🔹 GET JADWAL BY ID
    @staticmethod
    def get_jadwal_by_id(db: Session, jadwal_id: int):
        return db.query(Jadwal).filter(Jadwal.id == jadwal_id).first()

    # 🔹 GET JADWAL BY KELAS
    @staticmethod
    def get_jadwal_by_kelas(db: Session, kelas_id: int):
        return db.query(Jadwal).filter(Jadwal.kelas_id == kelas_id).all()

    # 🔹 GET JADWAL BY GURU
    @staticmethod
    def get_jadwal_by_guru(db: Session, guru_id: int):
        return db.query(Jadwal).filter(Jadwal.guru_id == guru_id).all()

    # 🔹 GET JADWAL BY HARI
    @staticmethod
    def get_jadwal_by_hari(db: Session, kelas_id: int, hari: str):
        return db.query(Jadwal).filter(
            Jadwal.kelas_id == kelas_id,
            Jadwal.hari == hari
        ).all()

    # 🔹 GET JADWAL BY MAPEL
    @staticmethod
    def get_jadwal_by_mapel(db: Session, mapel_id: int):
        return db.query(Jadwal).filter(Jadwal.mapel_id == mapel_id).all()

    # 🔹 UPDATE JADWAL
    @staticmethod
    def update_jadwal(db: Session, jadwal_id: int, data):
        jadwal = db.query(Jadwal).filter(Jadwal.id == jadwal_id).first()
        if not jadwal:
            return None

        if data.kelas_id:
            jadwal.kelas_id = data.kelas_id
        if data.mapel_id:
            jadwal.mapel_id = data.mapel_id
        if data.guru_id:
            jadwal.guru_id = data.guru_id
        if data.hari:
            jadwal.hari = data.hari
        if data.jam_mulai:
            jadwal.jam_mulai = data.jam_mulai
        if data.jam_selesai:
            jadwal.jam_selesai = data.jam_selesai

        db.commit()
        db.refresh(jadwal)
        return jadwal

    # 🔹 DELETE JADWAL
    @staticmethod
    def delete_jadwal(db: Session, jadwal_id: int):
        jadwal = db.query(Jadwal).filter(Jadwal.id == jadwal_id).first()
        if not jadwal:
            return False

        db.delete(jadwal)
        db.commit()
        return True