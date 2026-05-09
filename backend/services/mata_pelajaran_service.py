from sqlalchemy.orm import Session
from models.mata_pelajaran import MataPelajaran


class MataPelajaranService:

    # 🔹 CREATE MATA PELAJARAN
    @staticmethod
    def create_mata_pelajaran(db: Session, data):
        try:
            existing = db.query(MataPelajaran).filter(
                MataPelajaran.nama_mapel == data.nama_mapel
            ).first()
            if existing:
                raise ValueError("Nama mata pelajaran sudah digunakan")

            mapel = MataPelajaran(
                nama_mapel=data.nama_mapel
            )
            db.add(mapel)
            db.commit()
            db.refresh(mapel)
            return mapel
        except Exception:
            db.rollback()
            raise

    # 🔹 GET ALL MATA PELAJARAN
    @staticmethod
    def get_all_mata_pelajaran(db: Session):
        return db.query(MataPelajaran).all()

    # 🔹 GET MATA PELAJARAN BY ID
    @staticmethod
    def get_mata_pelajaran_by_id(db: Session, mapel_id: int):
        return db.query(MataPelajaran).filter(MataPelajaran.id == mapel_id).first()

    # 🔹 GET MATA PELAJARAN BY NAMA
    @staticmethod
    def get_mata_pelajaran_by_nama(db: Session, nama_mapel: str):
        return db.query(MataPelajaran).filter(MataPelajaran.nama_mapel == nama_mapel).first()

    # 🔹 UPDATE MATA PELAJARAN
    @staticmethod
    def update_mata_pelajaran(db: Session, mapel_id: int, data):
        try:
            mapel = db.query(MataPelajaran).filter(MataPelajaran.id == mapel_id).first()
            if not mapel:
                return None

            if data.nama_mapel:
                existing = db.query(MataPelajaran).filter(
                    MataPelajaran.nama_mapel == data.nama_mapel,
                    MataPelajaran.id != mapel_id,
                ).first()
                if existing:
                    raise ValueError("Nama mata pelajaran sudah digunakan")
                mapel.nama_mapel = data.nama_mapel

            db.commit()
            db.refresh(mapel)
            return mapel
        except Exception:
            db.rollback()
            raise

    # 🔹 DELETE MATA PELAJARAN
    @staticmethod
    def delete_mata_pelajaran(db: Session, mapel_id: int):
        mapel = db.query(MataPelajaran).filter(MataPelajaran.id == mapel_id).first()
        if not mapel:
            return False

        db.delete(mapel)
        db.commit()
        return True
