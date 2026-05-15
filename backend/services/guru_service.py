from sqlalchemy.orm import Session
from models.guru import Guru
from models.guru_mapel import GuruMapel
from models.kelas import Kelas
from models.mata_pelajaran import MataPelajaran
from core.security import hash_password


class GuruService:

    # 🔹 CREATE GURU
    @staticmethod
    def create_guru(db: Session, data):
        try:
            guru = Guru(
                nama=data.nama,
                email=data.email,
                password=hash_password(data.password),
                nip=data.nip,
                jenis_kelamin=data.jenis_kelamin,
                foto_url=data.foto_url,
            )
            db.add(guru)
            db.flush()

            for mapel_id in GuruService._requested_mapel_ids(data):
                if not db.query(MataPelajaran).filter(MataPelajaran.id == mapel_id).first():
                    raise ValueError("Mata pelajaran tidak ditemukan")
                db.add(GuruMapel(guru_id=guru.id, mapel_id=mapel_id))

            for kelas_id in GuruService._requested_kelas_asuh_ids(data):
                kelas = db.query(Kelas).filter(Kelas.id == kelas_id).first()
                if not kelas:
                    raise ValueError("Kelas asuh tidak ditemukan")
                GuruService._ensure_kelas_available_for_wali(kelas, guru.id)
                kelas.wali_kelas_id = guru.id

            db.commit()
            db.refresh(guru)
            return guru
        except Exception:
            db.rollback()
            raise

    # 🔹 GET ALL GURU
    @staticmethod
    def get_all_guru(db: Session):
        return db.query(Guru).all()

    @staticmethod
    def get_guru_by_mapel(db: Session, mapel_id: int):
        return (
            db.query(Guru)
            .join(GuruMapel, GuruMapel.guru_id == Guru.id)
            .filter(GuruMapel.mapel_id == mapel_id)
            .all()
        )

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
        try:
            guru = db.query(Guru).filter(Guru.id == guru_id).first()
            if not guru:
                return None

            if getattr(data, "nama", None):
                guru.nama = data.nama
            if getattr(data, "email", None):
                guru.email = data.email
            if getattr(data, "nip", None):
                guru.nip = data.nip
            if GuruService._field_was_sent(data, "jenis_kelamin"):
                guru.jenis_kelamin = data.jenis_kelamin
            if getattr(data, "foto_url", None) is not None:
                guru.foto_url = data.foto_url
            if getattr(data, "password", None):
                guru.password = hash_password(data.password)

            if GuruService._field_was_sent(data, "mapel_ids") or GuruService._field_was_sent(data, "mapel_id"):
                db.query(GuruMapel).filter(GuruMapel.guru_id == guru.id).delete()
                for mapel_id in GuruService._requested_mapel_ids(data):
                    if not db.query(MataPelajaran).filter(MataPelajaran.id == mapel_id).first():
                        raise ValueError("Mata pelajaran tidak ditemukan")
                    db.add(GuruMapel(guru_id=guru.id, mapel_id=mapel_id))

            if GuruService._field_was_sent(data, "kelas_asuh_ids") or GuruService._field_was_sent(data, "kelas_asuh_id"):
                db.query(Kelas).filter(Kelas.wali_kelas_id == guru.id).update(
                    {Kelas.wali_kelas_id: None}
                )

                for kelas_id in GuruService._requested_kelas_asuh_ids(data):
                    kelas = db.query(Kelas).filter(Kelas.id == kelas_id).first()
                    if not kelas:
                        raise ValueError("Kelas asuh tidak ditemukan")
                    GuruService._ensure_kelas_available_for_wali(kelas, guru.id)
                    kelas.wali_kelas_id = guru.id

            db.commit()
            db.refresh(guru)
            return guru
        except Exception:
            db.rollback()
            raise

    # 🔹 DELETE GURU
    @staticmethod
    def delete_guru(db: Session, guru_id: int):
        try:
            guru = db.query(Guru).filter(Guru.id == guru_id).first()
            if not guru:
                return False

            db.query(GuruMapel).filter(GuruMapel.guru_id == guru.id).delete()
            db.query(Kelas).filter(Kelas.wali_kelas_id == guru.id).update(
                {Kelas.wali_kelas_id: None}
            )
            db.delete(guru)
            db.commit()
            return True
        except Exception:
            db.rollback()
            raise

    @staticmethod
    def _requested_mapel_ids(data):
        if data.mapel_ids is not None:
            return list(dict.fromkeys(data.mapel_ids))
        if data.mapel_id:
            return [data.mapel_id]
        return []

    @staticmethod
    def _requested_kelas_asuh_ids(data):
        if data.kelas_asuh_ids is not None:
            if len(data.kelas_asuh_ids) > 1:
                raise ValueError("Guru hanya boleh menjadi wali untuk satu kelas")
            return list(dict.fromkeys(data.kelas_asuh_ids))
        if data.kelas_asuh_id:
            return [data.kelas_asuh_id]
        return []

    @staticmethod
    def _field_was_sent(data, field_name: str):
        fields_set = getattr(data, "model_fields_set", None)
        if fields_set is None:
            fields_set = getattr(data, "__fields_set__", set())
        return field_name in fields_set

    @staticmethod
    def _ensure_kelas_available_for_wali(kelas: Kelas, guru_id: int):
        if kelas.wali_kelas_id is not None and kelas.wali_kelas_id != guru_id:
            raise ValueError("Kelas ini sudah memiliki wali kelas")
