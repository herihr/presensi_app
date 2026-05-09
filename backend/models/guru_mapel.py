from sqlalchemy import Column, Integer, ForeignKey, UniqueConstraint
from sqlalchemy.orm import relationship
from core.database import Base


class GuruMapel(Base):
    __tablename__ = "guru_mapel"

    id = Column(Integer, primary_key=True, index=True)
    guru_id = Column(Integer, ForeignKey("guru.id"), nullable=False)
    mapel_id = Column(Integer, ForeignKey("mata_pelajaran.id"), nullable=False)

    # Relationships
    # 1 guru bisa mengajar lebih dari 1 mata pelajaran
    guru = relationship("Guru", back_populates="mapel_yang_diajar")
    mapel = relationship("MataPelajaran", back_populates="guru_mapel")

    __table_args__ = (
        UniqueConstraint("guru_id", "mapel_id", name="uq_guru_mapel_pair"),
    )
