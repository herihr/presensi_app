from pydantic import BaseModel, EmailStr
from typing import Optional


# ============ ADMIN ============

class AdminCreate(BaseModel):
    nama: str
    email: EmailStr
    password: str


class AdminUpdate(BaseModel):
    nama: Optional[str] = None
    email: Optional[EmailStr] = None
    password: Optional[str] = None


class AdminResponse(BaseModel):
    id: int
    nama: str
    email: str

    class Config:
        from_attributes = True


# ============ GURU ============

class GuruCreate(BaseModel):
    nama: str
    email: EmailStr
    password: str
    nip: str


class GuruUpdate(BaseModel):
    nama: Optional[str] = None
    email: Optional[EmailStr] = None
    nip: Optional[str] = None
    password: Optional[str] = None


class GuruResponse(BaseModel):
    id: int
    nama: str
    email: str
    nip: str

    class Config:
        from_attributes = True


# ============ SISWA ============

class SiswaCreate(BaseModel):
    nama: str
    nis: str
    kelas_id: int


class SiswaUpdate(BaseModel):
    nama: Optional[str] = None
    nis: Optional[str] = None
    kelas_id: Optional[int] = None


class SiswaResponse(BaseModel):
    id: int
    nama: str
    nis: str
    kelas_id: int

    class Config:
        from_attributes = True


# ============ KELAS ============

class KelasCreate(BaseModel):
    nama_kelas: str
    wali_kelas_id: int


class KelasUpdate(BaseModel):
    nama_kelas: Optional[str] = None
    wali_kelas_id: Optional[int] = None


class KelasResponse(BaseModel):
    id: int
    nama_kelas: str
    wali_kelas_id: int

    class Config:
        from_attributes = True


# ============ MATA PELAJARAN ============

class MataPelajaranCreate(BaseModel):
    nama_mapel: str


class MataPelajaranUpdate(BaseModel):
    nama_mapel: Optional[str] = None


class MataPelajaranResponse(BaseModel):
    id: int
    nama_mapel: str

    class Config:
        from_attributes = True


# ============ JADWAL ============

class JadwalCreate(BaseModel):
    kelas_id: int
    mapel_id: int
    guru_id: int
    hari: str
    jam_mulai: str
    jam_selesai: str


class JadwalUpdate(BaseModel):
    kelas_id: Optional[int] = None
    mapel_id: Optional[int] = None
    guru_id: Optional[int] = None
    hari: Optional[str] = None
    jam_mulai: Optional[str] = None
    jam_selesai: Optional[str] = None


class JadwalResponse(BaseModel):
    id: int
    kelas_id: int
    mapel_id: int
    guru_id: int
    hari: str
    jam_mulai: str
    jam_selesai: str

    class Config:
        from_attributes = True


# ============ PRESENSI ============

class PresensiCreate(BaseModel):
    siswa_id: int
    jadwal_id: int
    guru_id: int
    status: str
    tanggal: str
    jam_presensi: str


class PresensiUpdate(BaseModel):
    status: Optional[str] = None
    tanggal: Optional[str] = None
    jam_presensi: Optional[str] = None


class PresensiResponse(BaseModel):
    id: int
    siswa_id: int
    jadwal_id: int
    guru_id: int
    status: str
    tanggal: str
    jam_presensi: str

    class Config:
        from_attributes = True


# ============ EMBEDDING ============

class EmbeddingCreate(BaseModel):
    siswa_id: int
    embedding: list


class EmbeddingUpdate(BaseModel):
    embedding: list


class EmbeddingResponse(BaseModel):
    id: int
    siswa_id: int
    embedding: str

    class Config:
        from_attributes = True