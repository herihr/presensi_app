from sqlalchemy import Column, ForeignKey, Integer, String, UniqueConstraint
from sqlalchemy.orm import relationship

from core.database import Base


class SiswaKelas(Base):
    __tablename__ = "siswa_kelas"

    id = Column(Integer, primary_key=True, index=True)
    siswa_id = Column(Integer, ForeignKey("siswa.id"), nullable=False)
    kelas_id = Column(Integer, ForeignKey("kelas.id"), nullable=False)
    tahun_pelajaran_id = Column(
        Integer,
        ForeignKey("tahun_pelajaran.id"),
        nullable=False,
    )
    status = Column(String(20), nullable=False, default="aktif")

    siswa = relationship("Siswa", back_populates="riwayat_kelas")
    kelas = relationship("Kelas", back_populates="siswa_tahunan")
    tahun_pelajaran = relationship("TahunPelajaran", back_populates="siswa_kelas")

    __table_args__ = (
        UniqueConstraint(
            "siswa_id",
            "tahun_pelajaran_id",
            name="uq_siswa_kelas_siswa_tahun",
        ),
    )
