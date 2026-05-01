from sqlalchemy import Column, Integer, ForeignKey, String, DateTime
from sqlalchemy.orm import relationship
from core.database import Base

class Presensi(Base):
    __tablename__ = "presensi"

    id = Column(Integer, primary_key=True, index=True)
    siswa_id = Column(Integer, ForeignKey("siswa.id"))
    jadwal_id = Column(Integer, ForeignKey("jadwal.id"))
    # Hanya guru matapelajaran yang bisa melakukan presensi untuk jam pelajaran yang sedang berlangsung
    guru_id = Column(Integer, ForeignKey("guru.id"))
    status = Column(String(20))  # hadir, izin, sakit, alpha
    tanggal = Column(String(10))
    jam_presensi = Column(String(10))

    # Relationships
    siswa = relationship("Siswa", back_populates="presensi")
    jadwal = relationship("Jadwal", back_populates="presensi")
    guru = relationship("Guru", back_populates="presensi")