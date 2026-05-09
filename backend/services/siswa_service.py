from sqlalchemy.orm import Session
from models.kelas import Kelas
from models.siswa import Siswa


class SiswaService:

    # 🔹 CREATE SISWA
    @staticmethod
    def create_siswa(db: Session, data):
        try:
            if not db.query(Kelas).filter(Kelas.id == data.kelas_id).first():
                raise ValueError("Kelas tidak ditemukan")

            siswa = Siswa(
                nama=data.nama,
                nis=data.nis,
                kelas_id=data.kelas_id,
                alamat=data.alamat,
                foto_url=data.foto_url,
                embedding_status=data.embedding_status,
            )
            db.add(siswa)
            db.commit()
            db.refresh(siswa)
            return siswa
        except Exception:
            db.rollback()
            raise

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
        try:
            siswa = db.query(Siswa).filter(Siswa.id == siswa_id).first()
            if not siswa:
                return None

            if data.nama:
                siswa.nama = data.nama
            if data.nis:
                siswa.nis = data.nis
            if data.kelas_id:
                if not db.query(Kelas).filter(Kelas.id == data.kelas_id).first():
                    raise ValueError("Kelas tidak ditemukan")
                siswa.kelas_id = data.kelas_id
            if data.alamat is not None:
                siswa.alamat = data.alamat
            if data.foto_url is not None:
                siswa.foto_url = data.foto_url
            if data.embedding_status is not None:
                siswa.embedding_status = data.embedding_status

            db.commit()
            db.refresh(siswa)
            return siswa
        except Exception:
            db.rollback()
            raise

    # 🔹 DELETE SISWA
    @staticmethod
    def delete_siswa(db: Session, siswa_id: int):
        try:
            siswa = db.query(Siswa).filter(Siswa.id == siswa_id).first()
            if not siswa:
                return False

            db.delete(siswa)
            db.commit()
            return True
        except Exception:
            db.rollback()
            raise
