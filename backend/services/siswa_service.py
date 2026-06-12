from sqlalchemy.orm import Session
from models.embedding import Embedding
from models.kelas import Kelas
from models.presensi import Presensi
from models.siswa import Siswa
from models.siswa_kelas import SiswaKelas
from services.tahun_pelajaran_service import TahunPelajaranService


class SiswaService:

    # 🔹 CREATE SISWA
    @staticmethod
    def create_siswa(db: Session, data):
        try:
            if not db.query(Kelas).filter(Kelas.id == data.kelas_id).first():
                raise ValueError("Kelas tidak ditemukan")
            tahun_id = data.tahun_pelajaran_id or TahunPelajaranService.get_active(db).id

            siswa = Siswa(
                nama=data.nama,
                nis=data.nis,
                jenis_kelamin=data.jenis_kelamin,
                kelas_id=data.kelas_id,
                alamat=data.alamat,
                foto_url=data.foto_url,
                embedding_status=data.embedding_status,
            )
            db.add(siswa)
            db.flush()
            db.add(
                SiswaKelas(
                    siswa_id=siswa.id,
                    kelas_id=data.kelas_id,
                    tahun_pelajaran_id=tahun_id,
                    status="aktif",
                )
            )
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
    def get_siswa_by_kelas(
        db: Session,
        kelas_id: int,
        tahun_pelajaran_id: int | None = None,
    ):
        tahun_id = tahun_pelajaran_id or TahunPelajaranService.get_active(db).id
        siswa = (
            db.query(Siswa)
            .join(SiswaKelas, SiswaKelas.siswa_id == Siswa.id)
            .filter(
                SiswaKelas.kelas_id == kelas_id,
                SiswaKelas.tahun_pelajaran_id == tahun_id,
                SiswaKelas.status == "aktif",
            )
            .all()
        )
        if siswa:
            return siswa
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
            if "jenis_kelamin" in getattr(data, "model_fields_set", getattr(data, "__fields_set__", set())):
                siswa.jenis_kelamin = data.jenis_kelamin
            if data.kelas_id:
                if not db.query(Kelas).filter(Kelas.id == data.kelas_id).first():
                    raise ValueError("Kelas tidak ditemukan")
                siswa.kelas_id = data.kelas_id
                tahun_id = data.tahun_pelajaran_id or TahunPelajaranService.get_active(db).id
                SiswaService._upsert_siswa_kelas(
                    db,
                    siswa_id=siswa.id,
                    kelas_id=data.kelas_id,
                    tahun_pelajaran_id=tahun_id,
                    status="aktif",
                )
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

            db.query(Embedding).filter(Embedding.siswa_id == siswa_id).delete(
                synchronize_session=False
            )
            db.query(Presensi).filter(Presensi.siswa_id == siswa_id).delete(
                synchronize_session=False
            )
            db.query(SiswaKelas).filter(SiswaKelas.siswa_id == siswa_id).delete(
                synchronize_session=False
            )
            db.delete(siswa)
            db.commit()
            return True
        except Exception:
            db.rollback()
            raise

    @staticmethod
    def naik_kelas(db: Session, data):
        try:
            if not TahunPelajaranService.get_by_id(db, data.tahun_pelajaran_id):
                raise ValueError("Tahun pelajaran tidak ditemukan")
            for item in data.items:
                siswa = db.query(Siswa).filter(Siswa.id == item.siswa_id).first()
                if not siswa:
                    raise ValueError(f"Siswa ID {item.siswa_id} tidak ditemukan")
                if not db.query(Kelas).filter(Kelas.id == item.kelas_id).first():
                    raise ValueError(f"Kelas ID {item.kelas_id} tidak ditemukan")
                SiswaService._upsert_siswa_kelas(
                    db,
                    siswa_id=item.siswa_id,
                    kelas_id=item.kelas_id,
                    tahun_pelajaran_id=data.tahun_pelajaran_id,
                    status=item.status,
                )
                if item.status == "aktif":
                    siswa.kelas_id = item.kelas_id

            db.commit()
            return True
        except Exception:
            db.rollback()
            raise

    @staticmethod
    def _upsert_siswa_kelas(
        db: Session,
        siswa_id: int,
        kelas_id: int,
        tahun_pelajaran_id: int,
        status: str,
    ):
        existing = (
            db.query(SiswaKelas)
            .filter(
                SiswaKelas.siswa_id == siswa_id,
                SiswaKelas.tahun_pelajaran_id == tahun_pelajaran_id,
            )
            .first()
        )
        if existing:
            existing.kelas_id = kelas_id
            existing.status = status
            return existing

        item = SiswaKelas(
            siswa_id=siswa_id,
            kelas_id=kelas_id,
            tahun_pelajaran_id=tahun_pelajaran_id,
            status=status,
        )
        db.add(item)
        return item
