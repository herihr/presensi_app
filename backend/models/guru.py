from sqlalchemy import Column, Integer, String, Text
from sqlalchemy.orm import relationship
from core.database import Base


class Guru(Base):
    __tablename__ = "guru"

    id = Column(Integer, primary_key=True, index=True)
    nama = Column(String(100), nullable=False)
    jenis_kelamin = Column(String(20), nullable=True)
    email = Column(String(100), unique=True, nullable=False)
    password = Column(String(255), nullable=False)
    nip = Column(String(50), unique=True, nullable=False)
    foto_url = Column(Text, nullable=True)

    @property
    def mapel_id(self):
        return self.mapel_yang_diajar[0].mapel_id if self.mapel_yang_diajar else None

    @property
    def mapel_ids(self):
        return [item.mapel_id for item in self.mapel_yang_diajar]

    @property
    def kelas_asuh_id(self):
        return self.kelas_yang_diwalikan[0].id if self.kelas_yang_diwalikan else None

    @property
    def kelas_asuh_ids(self):
        return [kelas.id for kelas in self.kelas_yang_diwalikan]

    # Relationships
    # 1 guru dapat menjadi wali untuk lebih dari 1 kelas
    kelas_yang_diwalikan = relationship("Kelas", back_populates="wali_kelas")
    # 1 guru dapat mengajar lebih dari 1 mata pelajaran
    mapel_yang_diajar = relationship("GuruMapel", back_populates="guru")
    jadwal = relationship("Jadwal", back_populates="guru")
    # Hanya guru matapelajaran yang bisa melakukan presensi
    presensi = relationship("Presensi", back_populates="guru")
