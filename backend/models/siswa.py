from sqlalchemy import Column, Integer, String, ForeignKey
from sqlalchemy.orm import relationship
from core.database import Base


class Siswa(Base):
    __tablename__ = "siswa"

    id = Column(Integer, primary_key=True, index=True)
    nama = Column(String(100), nullable=False)
    nis = Column(String(50), unique=True, nullable=False)
    jenis_kelamin = Column(String(20), nullable=True)
    kelas_id = Column(Integer, ForeignKey("kelas.id"), nullable=False)
    alamat = Column(String(255), nullable=True)
    foto_url = Column(String(255), nullable=True)
    embedding_status = Column(String(30), nullable=False, default="belum_diproses")

    # Relationships
    # 1 siswa hanya ada pada 1 kelas
    kelas = relationship("Kelas", back_populates="siswa")
    # 1 siswa memiliki lebih dari 1 embedding wajah
    embeddings = relationship("Embedding", back_populates="siswa")
    presensi = relationship("Presensi", back_populates="siswa")
