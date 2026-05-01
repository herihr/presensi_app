from sqlalchemy import Column, Integer, String, ForeignKey
from sqlalchemy.orm import relationship
from core.database import Base

class Guru(Base):
    __tablename__ = "guru"

    id = Column(Integer, primary_key=True, index=True)
    nama = Column(String(100))
    email = Column(String(100), unique=True)
    password = Column(String(255))
    nip = Column(String(50), unique=True)

    # Relationships
    # 1 guru hanya menjadi wali kelas pada 1 kelas
    kelas_yang_diwalikan = relationship("Kelas", back_populates="wali_kelas", uselist=False)
    # 1 guru hanya menjadi guru mata pelajaran pada 1 matapelajaran
    mapel_yang_diajar = relationship("GuruMapel", back_populates="guru", uselist=False)
    jadwal = relationship("Jadwal", back_populates="guru")
    # Hanya guru matapelajaran yang bisa melakukan presensi
    presensi = relationship("Presensi", back_populates="guru")