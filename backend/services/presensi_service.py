from sqlalchemy.orm import Session
from models.presensi import Presensi


class PresensiService:

    # 🔹 CREATE PRESENSI
    @staticmethod
    def create_presensi(db: Session, data):
        presensi = Presensi(
            siswa_id=data.siswa_id,
            jadwal_id=data.jadwal_id,
            guru_id=data.guru_id,
            status=data.status,
            tanggal=data.tanggal,
            jam_presensi=data.jam_presensi
        )
        db.add(presensi)
        db.commit()
        db.refresh(presensi)
        return presensi

    # 🔹 GET ALL PRESENSI
    @staticmethod
    def get_all_presensi(db: Session):
        return db.query(Presensi).all()

    # 🔹 GET PRESENSI BY ID
    @staticmethod
    def get_presensi_by_id(db: Session, presensi_id: int):
        return db.query(Presensi).filter(Presensi.id == presensi_id).first()

    # 🔹 GET PRESENSI BY SISWA
    @staticmethod
    def get_presensi_by_siswa(db: Session, siswa_id: int):
        return db.query(Presensi).filter(Presensi.siswa_id == siswa_id).all()

    # 🔹 GET PRESENSI BY JADWAL
    @staticmethod
    def get_presensi_by_jadwal(db: Session, jadwal_id: int):
        return db.query(Presensi).filter(Presensi.jadwal_id == jadwal_id).all()

    # 🔹 GET PRESENSI BY GURU
    @staticmethod
    def get_presensi_by_guru(db: Session, guru_id: int):
        return db.query(Presensi).filter(Presensi.guru_id == guru_id).all()

    # 🔹 GET PRESENSI BY TANGGAL
    @staticmethod
    def get_presensi_by_tanggal(db: Session, tanggal: str):
        return db.query(Presensi).filter(Presensi.tanggal == tanggal).all()

    # 🔹 GET PRESENSI BY SISWA & JADWAL
    @staticmethod
    def get_presensi_by_siswa_jadwal(db: Session, siswa_id: int, jadwal_id: int):
        return db.query(Presensi).filter(
            Presensi.siswa_id == siswa_id,
            Presensi.jadwal_id == jadwal_id
        ).first()

    # 🔹 UPDATE PRESENSI
    @staticmethod
    def update_presensi(db: Session, presensi_id: int, data):
        presensi = db.query(Presensi).filter(Presensi.id == presensi_id).first()
        if not presensi:
            return None

        if data.status:
            presensi.status = data.status
        if data.tanggal:
            presensi.tanggal = data.tanggal
        if data.jam_presensi:
            presensi.jam_presensi = data.jam_presensi

        db.commit()
        db.refresh(presensi)
        return presensi

    # 🔹 DELETE PRESENSI
    @staticmethod
    def delete_presensi(db: Session, presensi_id: int):
        presensi = db.query(Presensi).filter(Presensi.id == presensi_id).first()
        if not presensi:
            return False

        db.delete(presensi)
        db.commit()
        return True