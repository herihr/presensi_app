from sqlalchemy import Column, Integer, ForeignKey, Text
from sqlalchemy.orm import relationship
from core.database import Base

class Embedding(Base):
    __tablename__ = "embeddings"

    id = Column(Integer, primary_key=True, index=True)
    siswa_id = Column(Integer, ForeignKey("siswa.id"), nullable=False)
    embedding = Column(Text)  # simpan vector JSON/string

    # Relationships
    # 1 siswa memiliki lebih dari 1 embedding wajah
    siswa = relationship("Siswa", back_populates="embeddings")
