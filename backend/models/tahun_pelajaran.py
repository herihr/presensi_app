from sqlalchemy import Boolean, Column, Date, Integer, String
from sqlalchemy.orm import relationship

from core.database import Base


class TahunPelajaran(Base):
    __tablename__ = "tahun_pelajaran"

    id = Column(Integer, primary_key=True, index=True)
    nama = Column(String(20), unique=True, nullable=False)
    tanggal_mulai = Column(Date, nullable=True)
    tanggal_selesai = Column(Date, nullable=True)
    is_aktif = Column(Boolean, nullable=False, default=False)

    siswa_kelas = relationship("SiswaKelas", back_populates="tahun_pelajaran")
    wali_kelas = relationship("WaliKelas", back_populates="tahun_pelajaran")
    jadwal = relationship("Jadwal", back_populates="tahun_pelajaran")
