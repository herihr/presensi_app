from datetime import date

from sqlalchemy.orm import Session

from models.tahun_pelajaran import TahunPelajaran


class TahunPelajaranService:
    @staticmethod
    def get_active(db: Session):
        active = db.query(TahunPelajaran).filter(TahunPelajaran.is_aktif == True).first()  # noqa: E712
        if active:
            return active

        name = TahunPelajaranService.default_name()
        existing = db.query(TahunPelajaran).filter(TahunPelajaran.nama == name).first()
        if existing:
            existing.is_aktif = True
            db.commit()
            db.refresh(existing)
            return existing

        start_year = int(name.split("/")[0])
        created = TahunPelajaran(
            nama=name,
            tanggal_mulai=date(start_year, 7, 1),
            tanggal_selesai=date(start_year + 1, 6, 30),
            is_aktif=True,
        )
        db.add(created)
        db.commit()
        db.refresh(created)
        return created

    @staticmethod
    def default_name():
        today = date.today()
        start_year = today.year if today.month >= 7 else today.year - 1
        return f"{start_year}/{start_year + 1}"

    @staticmethod
    def create(db: Session, data):
        try:
            if data.is_aktif:
                db.query(TahunPelajaran).update({TahunPelajaran.is_aktif: False})
            item = TahunPelajaran(
                nama=data.nama,
                tanggal_mulai=data.tanggal_mulai,
                tanggal_selesai=data.tanggal_selesai,
                is_aktif=data.is_aktif,
            )
            db.add(item)
            db.commit()
            db.refresh(item)
            return item
        except Exception:
            db.rollback()
            raise

    @staticmethod
    def get_all(db: Session):
        return db.query(TahunPelajaran).order_by(TahunPelajaran.nama.desc()).all()

    @staticmethod
    def get_by_id(db: Session, tahun_id: int):
        return db.query(TahunPelajaran).filter(TahunPelajaran.id == tahun_id).first()

    @staticmethod
    def update(db: Session, tahun_id: int, data):
        try:
            item = TahunPelajaranService.get_by_id(db, tahun_id)
            if not item:
                return None

            if data.nama is not None:
                item.nama = data.nama
            if data.tanggal_mulai is not None:
                item.tanggal_mulai = data.tanggal_mulai
            if data.tanggal_selesai is not None:
                item.tanggal_selesai = data.tanggal_selesai
            if data.is_aktif is not None:
                if data.is_aktif:
                    db.query(TahunPelajaran).filter(TahunPelajaran.id != tahun_id).update(
                        {TahunPelajaran.is_aktif: False}
                    )
                item.is_aktif = data.is_aktif

            db.commit()
            db.refresh(item)
            return item
        except Exception:
            db.rollback()
            raise

    @staticmethod
    def set_active(db: Session, tahun_id: int):
        try:
            item = TahunPelajaranService.get_by_id(db, tahun_id)
            if not item:
                return None

            db.query(TahunPelajaran).update({TahunPelajaran.is_aktif: False})
            item.is_aktif = True
            db.commit()
            db.refresh(item)
            return item
        except Exception:
            db.rollback()
            raise
