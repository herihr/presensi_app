from sqlalchemy import Column, Integer, String, ForeignKey
from sqlalchemy.orm import relationship
from core.database import Base


class Kelas(Base):
    __tablename__ = "kelas"

    id = Column(Integer, primary_key=True, index=True)
    nama_kelas = Column(String(50), unique=True, nullable=False)
    wali_kelas_id = Column(Integer, ForeignKey("guru.id"), unique=True, nullable=True)

    # Relationships
    # 1 kelas hanya 1 wali kelas saja
    wali_kelas = relationship("Guru", back_populates="kelas_yang_diwalikan")
    wali_kelas_tahunan = relationship("WaliKelas", back_populates="kelas")
    # 1 kelas berisi banyak siswa
    siswa = relationship("Siswa", back_populates="kelas")
    siswa_tahunan = relationship("SiswaKelas", back_populates="kelas")
    # 1 kelas punya banyak mata pelajaran (melalui jadwal)
    jadwal = relationship("Jadwal", back_populates="kelas")
