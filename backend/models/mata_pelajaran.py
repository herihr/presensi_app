from sqlalchemy import Column, Integer, String
from sqlalchemy.orm import relationship
from core.database import Base

class MataPelajaran(Base):
    __tablename__ = "mata_pelajaran"

    id = Column(Integer, primary_key=True, index=True)
    nama_mapel = Column(String(100))

    # Relationships
    # 1 mata pelajaran punya lebih dari 1 guru
    guru_mapel = relationship("GuruMapel", back_populates="mapel")
    # 1 mata pelajaran bisa berada di beberapa kelas sekaligus (melalui jadwal)
    jadwal = relationship("Jadwal", back_populates="mapel")