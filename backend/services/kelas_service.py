from sqlalchemy.orm import Session
from models.guru import Guru
from models.kelas import Kelas
from models.wali_kelas import WaliKelas
from services.tahun_pelajaran_service import TahunPelajaranService


class KelasService:

    # 🔹 CREATE KELAS
    @staticmethod
    def create_kelas(db: Session, data):
        try:
            KelasService._validate_wali_kelas(db, data.wali_kelas_id)

            kelas = Kelas(
                nama_kelas=data.nama_kelas,
                wali_kelas_id=data.wali_kelas_id,
            )
            db.add(kelas)
            db.flush()
            if data.wali_kelas_id:
                KelasService._upsert_wali_kelas_tahunan(
                    db,
                    guru_id=data.wali_kelas_id,
                    kelas_id=kelas.id,
                    tahun_pelajaran_id=TahunPelajaranService.get_active(db).id,
                )
            db.commit()
            db.refresh(kelas)
            return kelas
        except Exception:
            db.rollback()
            raise

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
        try:
            kelas = db.query(Kelas).filter(Kelas.id == kelas_id).first()
            if not kelas:
                return None

            if data.nama_kelas:
                kelas.nama_kelas = data.nama_kelas
            if data.wali_kelas_id is not None:
                KelasService._validate_wali_kelas(
                    db,
                    data.wali_kelas_id,
                    exclude_kelas_id=kelas_id,
                )
                kelas.wali_kelas_id = data.wali_kelas_id
                if data.wali_kelas_id:
                    KelasService._upsert_wali_kelas_tahunan(
                        db,
                        guru_id=data.wali_kelas_id,
                        kelas_id=kelas.id,
                        tahun_pelajaran_id=TahunPelajaranService.get_active(db).id,
                    )

            db.commit()
            db.refresh(kelas)
            return kelas
        except Exception:
            db.rollback()
            raise

    # 🔹 DELETE KELAS
    @staticmethod
    def delete_kelas(db: Session, kelas_id: int):
        kelas = db.query(Kelas).filter(Kelas.id == kelas_id).first()
        if not kelas:
            return False

        db.delete(kelas)
        db.commit()
        return True

    @staticmethod
    def _validate_wali_kelas(
        db: Session,
        wali_kelas_id: int | None,
        exclude_kelas_id: int | None = None,
    ):
        if not wali_kelas_id:
            return

        if not db.query(Guru).filter(Guru.id == wali_kelas_id).first():
            raise ValueError("Wali kelas tidak ditemukan")

        query = db.query(Kelas).filter(Kelas.wali_kelas_id == wali_kelas_id)
        if exclude_kelas_id is not None:
            query = query.filter(Kelas.id != exclude_kelas_id)

        if query.first():
            raise ValueError("Guru ini sudah menjadi wali kelas lain")

    @staticmethod
    def _upsert_wali_kelas_tahunan(
        db: Session,
        guru_id: int,
        kelas_id: int,
        tahun_pelajaran_id: int,
    ):
        db.query(WaliKelas).filter(
            WaliKelas.kelas_id == kelas_id,
            WaliKelas.tahun_pelajaran_id == tahun_pelajaran_id,
        ).delete(synchronize_session=False)
        db.add(
            WaliKelas(
                guru_id=guru_id,
                kelas_id=kelas_id,
                tahun_pelajaran_id=tahun_pelajaran_id,
            )
        )
