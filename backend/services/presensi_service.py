from sqlalchemy.orm import Session

from models.guru import Guru
from models.jadwal import Jadwal
from models.presensi import Presensi
from models.siswa import Siswa


class PresensiService:

    @staticmethod
    def create_presensi(db: Session, data):
        try:
            PresensiService._validate_create_data(
                db,
                siswa_id=data.siswa_id,
                jadwal_id=data.jadwal_id,
                guru_id=data.guru_id,
                tanggal=data.tanggal,
            )

            presensi = Presensi(
                siswa_id=data.siswa_id,
                jadwal_id=data.jadwal_id,
                guru_id=data.guru_id,
                status=data.status,
                tanggal=data.tanggal,
                jam_presensi=data.jam_presensi,
            )
            db.add(presensi)
            db.commit()
            db.refresh(presensi)
            return presensi
        except Exception:
            db.rollback()
            raise

    @staticmethod
    def get_all_presensi(db: Session):
        return db.query(Presensi).all()

    @staticmethod
    def get_presensi_by_id(db: Session, presensi_id: int):
        return db.query(Presensi).filter(Presensi.id == presensi_id).first()

    @staticmethod
    def get_presensi_by_siswa(db: Session, siswa_id: int):
        return db.query(Presensi).filter(Presensi.siswa_id == siswa_id).all()

    @staticmethod
    def get_presensi_by_jadwal(db: Session, jadwal_id: int):
        return db.query(Presensi).filter(Presensi.jadwal_id == jadwal_id).all()

    @staticmethod
    def get_presensi_by_guru(db: Session, guru_id: int):
        return db.query(Presensi).filter(Presensi.guru_id == guru_id).all()

    @staticmethod
    def get_presensi_by_tanggal(db: Session, tanggal: str):
        return db.query(Presensi).filter(Presensi.tanggal == tanggal).all()

    @staticmethod
    def get_presensi_by_siswa_jadwal(db: Session, siswa_id: int, jadwal_id: int):
        return db.query(Presensi).filter(
            Presensi.siswa_id == siswa_id,
            Presensi.jadwal_id == jadwal_id,
        ).first()

    @staticmethod
    def update_presensi(db: Session, presensi_id: int, data):
        try:
            presensi = db.query(Presensi).filter(Presensi.id == presensi_id).first()
            if not presensi:
                return None

            tanggal = data.tanggal if data.tanggal is not None else presensi.tanggal
            PresensiService._validate_duplicate(
                db,
                siswa_id=presensi.siswa_id,
                jadwal_id=presensi.jadwal_id,
                tanggal=tanggal,
                exclude_presensi_id=presensi_id,
            )

            if data.status is not None:
                presensi.status = data.status
            if data.tanggal is not None:
                presensi.tanggal = data.tanggal
            if data.jam_presensi is not None:
                presensi.jam_presensi = data.jam_presensi

            db.commit()
            db.refresh(presensi)
            return presensi
        except Exception:
            db.rollback()
            raise

    @staticmethod
    def delete_presensi(db: Session, presensi_id: int):
        presensi = db.query(Presensi).filter(Presensi.id == presensi_id).first()
        if not presensi:
            return False

        db.delete(presensi)
        db.commit()
        return True

    @staticmethod
    def _validate_create_data(
        db: Session,
        siswa_id: int,
        jadwal_id: int,
        guru_id: int,
        tanggal: str,
    ):
        siswa = db.query(Siswa).filter(Siswa.id == siswa_id).first()
        if not siswa:
            raise ValueError("Siswa tidak ditemukan")

        jadwal = db.query(Jadwal).filter(Jadwal.id == jadwal_id).first()
        if not jadwal:
            raise ValueError("Jadwal tidak ditemukan")

        if not db.query(Guru).filter(Guru.id == guru_id).first():
            raise ValueError("Guru tidak ditemukan")

        if siswa.kelas_id != jadwal.kelas_id:
            raise ValueError("Siswa tidak berada di kelas jadwal ini")

        if guru_id != jadwal.guru_id:
            raise ValueError("Guru tidak sesuai dengan guru pada jadwal")

        PresensiService._validate_duplicate(
            db,
            siswa_id=siswa_id,
            jadwal_id=jadwal_id,
            tanggal=tanggal,
        )

    @staticmethod
    def _validate_duplicate(
        db: Session,
        siswa_id: int,
        jadwal_id: int,
        tanggal: str,
        exclude_presensi_id: int | None = None,
    ):
        query = db.query(Presensi).filter(
            Presensi.siswa_id == siswa_id,
            Presensi.jadwal_id == jadwal_id,
            Presensi.tanggal == tanggal,
        )

        if exclude_presensi_id is not None:
            query = query.filter(Presensi.id != exclude_presensi_id)

        if query.first():
            raise ValueError("Presensi siswa pada jadwal dan tanggal ini sudah ada")
