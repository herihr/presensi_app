from sqlalchemy import Column, ForeignKey, Integer, UniqueConstraint
from sqlalchemy.orm import relationship

from core.database import Base


class WaliKelas(Base):
    __tablename__ = "wali_kelas"

    id = Column(Integer, primary_key=True, index=True)
    guru_id = Column(Integer, ForeignKey("guru.id"), nullable=False)
    kelas_id = Column(Integer, ForeignKey("kelas.id"), nullable=False)
    tahun_pelajaran_id = Column(
        Integer,
        ForeignKey("tahun_pelajaran.id"),
        nullable=False,
    )

    guru = relationship("Guru", back_populates="wali_kelas_tahunan")
    kelas = relationship("Kelas", back_populates="wali_kelas_tahunan")
    tahun_pelajaran = relationship("TahunPelajaran", back_populates="wali_kelas")

    __table_args__ = (
        UniqueConstraint(
            "kelas_id",
            "tahun_pelajaran_id",
            name="uq_wali_kelas_kelas_tahun",
        ),
        UniqueConstraint(
            "guru_id",
            "tahun_pelajaran_id",
            name="uq_wali_kelas_guru_tahun",
        ),
    )
