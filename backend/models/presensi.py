from sqlalchemy import Column, Integer, ForeignKey, String, UniqueConstraint
from sqlalchemy.orm import relationship
from core.database import Base


class Presensi(Base):
    __tablename__ = "presensi"

    id = Column(Integer, primary_key=True, index=True)
    siswa_id = Column(Integer, ForeignKey("siswa.id"), nullable=False)
    jadwal_id = Column(Integer, ForeignKey("jadwal.id"), nullable=False)
    # Hanya guru matapelajaran yang bisa melakukan presensi untuk jam pelajaran yang sedang berlangsung
    guru_id = Column(Integer, ForeignKey("guru.id"), nullable=False)
    status = Column(String(20), nullable=False)  # hadir, izin, sakit, alpha
    tanggal = Column(String(10), nullable=False)
    jam_presensi = Column(String(10), nullable=False)

    __table_args__ = (
        UniqueConstraint("siswa_id", "jadwal_id", "tanggal", name="uq_presensi_siswa_jadwal_tanggal"),
    )

    # Relationships
    siswa = relationship("Siswa", back_populates="presensi")
    jadwal = relationship("Jadwal", back_populates="presensi")
    guru = relationship("Guru", back_populates="presensi")
