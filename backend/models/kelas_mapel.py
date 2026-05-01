from sqlalchemy import Column, Integer, ForeignKey
from core.database import Base

class KelasMapel(Base):
    __tablename__ = "kelas_mapel"

    id = Column(Integer, primary_key=True, index=True)
    kelas_id = Column(Integer, ForeignKey("kelas.id"))
    mapel_id = Column(Integer, ForeignKey("mata_pelajaran.id"))