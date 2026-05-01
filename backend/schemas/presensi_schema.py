from pydantic import BaseModel

class PresensiCreate(BaseModel):
    siswa_id: int
    jadwal_id: int