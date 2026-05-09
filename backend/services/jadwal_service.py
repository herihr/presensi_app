from sqlalchemy.orm import Session
from models.guru import Guru
from models.guru_mapel import GuruMapel
from models.jadwal import Jadwal
from models.kelas import Kelas
from models.mata_pelajaran import MataPelajaran


class JadwalService:

    # 🔹 CREATE JADWAL
    @staticmethod
    def create_jadwal(db: Session, data):
        try:
            JadwalService._validate_references(db, data.kelas_id, data.guru_id, data.mapel_id)
            JadwalService._validate_no_overlap(
                db,
                kelas_id=data.kelas_id,
                guru_id=data.guru_id,
                hari=data.hari,
                jam_mulai=data.jam_mulai,
                jam_selesai=data.jam_selesai,
            )

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
        except Exception:
            db.rollback()
            raise

    @staticmethod
    def create_jadwal_batch(db: Session, data):
        try:
            items = data.items
            JadwalService._validate_batch_payload(items)

            for item in items:
                JadwalService._validate_references(
                    db,
                    item.kelas_id,
                    item.guru_id,
                    item.mapel_id,
                )
                JadwalService._validate_no_overlap(
                    db,
                    kelas_id=item.kelas_id,
                    guru_id=item.guru_id,
                    hari=item.hari,
                    jam_mulai=item.jam_mulai,
                    jam_selesai=item.jam_selesai,
                )

            jadwal_list = [
                Jadwal(
                    kelas_id=item.kelas_id,
                    mapel_id=item.mapel_id,
                    guru_id=item.guru_id,
                    hari=item.hari,
                    jam_mulai=item.jam_mulai,
                    jam_selesai=item.jam_selesai,
                )
                for item in items
            ]

            db.add_all(jadwal_list)
            db.commit()
            for jadwal in jadwal_list:
                db.refresh(jadwal)
            return jadwal_list
        except Exception:
            db.rollback()
            raise

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
        try:
            jadwal = db.query(Jadwal).filter(Jadwal.id == jadwal_id).first()
            if not jadwal:
                return None

            kelas_id = data.kelas_id or jadwal.kelas_id
            guru_id = data.guru_id or jadwal.guru_id
            mapel_id = data.mapel_id or jadwal.mapel_id
            hari = data.hari or jadwal.hari
            jam_mulai = data.jam_mulai or jadwal.jam_mulai
            jam_selesai = data.jam_selesai or jadwal.jam_selesai

            if jam_mulai >= jam_selesai:
                raise ValueError("Jam mulai harus lebih awal dari jam selesai")

            JadwalService._validate_references(db, kelas_id, guru_id, mapel_id)
            JadwalService._validate_no_overlap(
                db,
                kelas_id=kelas_id,
                guru_id=guru_id,
                hari=hari,
                jam_mulai=jam_mulai,
                jam_selesai=jam_selesai,
                exclude_jadwal_id=jadwal_id,
            )

            jadwal.kelas_id = kelas_id
            jadwal.mapel_id = mapel_id
            jadwal.guru_id = guru_id
            jadwal.hari = hari
            jadwal.jam_mulai = jam_mulai
            jadwal.jam_selesai = jam_selesai

            db.commit()
            db.refresh(jadwal)
            return jadwal
        except Exception:
            db.rollback()
            raise

    # 🔹 DELETE JADWAL
    @staticmethod
    def delete_jadwal(db: Session, jadwal_id: int):
        jadwal = db.query(Jadwal).filter(Jadwal.id == jadwal_id).first()
        if not jadwal:
            return False

        db.delete(jadwal)
        db.commit()
        return True

    @staticmethod
    def _validate_references(db: Session, kelas_id: int, guru_id: int, mapel_id: int):
        if not db.query(Kelas).filter(Kelas.id == kelas_id).first():
            raise ValueError("Kelas tidak ditemukan")
        if not db.query(Guru).filter(Guru.id == guru_id).first():
            raise ValueError("Guru tidak ditemukan")
        if not db.query(MataPelajaran).filter(MataPelajaran.id == mapel_id).first():
            raise ValueError("Mata pelajaran tidak ditemukan")
        if not db.query(GuruMapel).filter(
            GuruMapel.guru_id == guru_id,
            GuruMapel.mapel_id == mapel_id,
        ).first():
            raise ValueError("Guru belum terdaftar mengajar mata pelajaran ini")

    @staticmethod
    def _validate_no_overlap(
        db: Session,
        kelas_id: int,
        guru_id: int,
        hari: str,
        jam_mulai: str,
        jam_selesai: str,
        exclude_jadwal_id: int | None = None,
    ):
        query = db.query(Jadwal).filter(
            Jadwal.hari == hari,
            Jadwal.jam_mulai < jam_selesai,
            Jadwal.jam_selesai > jam_mulai,
        )

        if exclude_jadwal_id is not None:
            query = query.filter(Jadwal.id != exclude_jadwal_id)

        guru_conflict = query.filter(Jadwal.guru_id == guru_id).first()
        if guru_conflict:
            raise ValueError("Jadwal guru bentrok dengan jadwal lain")

        kelas_conflict = query.filter(Jadwal.kelas_id == kelas_id).first()
        if kelas_conflict:
            raise ValueError("Jadwal kelas bentrok dengan jadwal lain")

    @staticmethod
    def _validate_batch_payload(items):
        seen_mapel = set()
        for item in items:
            mapel_key = (item.kelas_id, item.hari, item.mapel_id)
            if mapel_key in seen_mapel:
                raise ValueError("Mata pelajaran dalam satu jadwal tidak boleh sama")
            seen_mapel.add(mapel_key)

        for index, current in enumerate(items):
            for other in items[index + 1:]:
                if current.hari != other.hari:
                    continue
                if not JadwalService._times_overlap(
                    current.jam_mulai,
                    current.jam_selesai,
                    other.jam_mulai,
                    other.jam_selesai,
                ):
                    continue
                if current.guru_id == other.guru_id:
                    raise ValueError("Jadwal guru bentrok di data yang dikirim")
                if current.kelas_id == other.kelas_id:
                    raise ValueError("Jadwal kelas bentrok di data yang dikirim")

    @staticmethod
    def _times_overlap(start_a: str, end_a: str, start_b: str, end_b: str):
        return start_a < end_b and end_a > start_b
