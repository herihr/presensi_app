from sqlalchemy import Column, Integer, ForeignKey, String
from sqlalchemy.orm import relationship
from core.database import Base


class Jadwal(Base):
    __tablename__ = "jadwal"

    id = Column(Integer, primary_key=True, index=True)
    kelas_id = Column(Integer, ForeignKey("kelas.id"), nullable=False)
    mapel_id = Column(Integer, ForeignKey("mata_pelajaran.id"), nullable=False)
    guru_id = Column(Integer, ForeignKey("guru.id"), nullable=False)
    hari = Column(String(20), nullable=False)
    jam_mulai = Column(String(10), nullable=False)
    jam_selesai = Column(String(10), nullable=False)

    # Relationships
    # Jadwal untuk setiap kelas yang berisi jam dan mata pelajaran yang sedang berlangsung
    kelas = relationship("Kelas", back_populates="jadwal")
    mapel = relationship("MataPelajaran", back_populates="jadwal")
    guru = relationship("Guru", back_populates="jadwal")
    # Presensi dicatat untuk setiap jadwal (jam pelajaran)
    presensi = relationship("Presensi", back_populates="jadwal")
