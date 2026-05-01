from sqlalchemy import Column, Integer, String
from core.database import Base

class Admin(Base):
    __tablename__ = "admin"

    id = Column(Integer, primary_key=True, index=True)
    nama = Column(String(100))
    email = Column(String(100), unique=True)
    password = Column(String(255))