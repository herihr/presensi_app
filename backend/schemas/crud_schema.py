import json
from typing import Any, Literal, Optional

from pydantic import BaseModel, EmailStr, Field, field_validator, model_validator


ValidHari = Literal["Senin", "Selasa", "Rabu", "Kamis", "Jumat", "Sabtu", "Minggu"]
EmbeddingStatus = Literal["belum_diproses", "diproses", "gagal"]
PresensiStatus = Literal["hadir", "izin", "sakit", "alpha"]


def _normalize_time(value: str) -> str:
    value = str(value).strip().replace(".", ":")
    parts = value.split(":")
    if len(parts) != 2:
        raise ValueError("Format jam harus HH:MM")

    hour = int(parts[0])
    minute = int(parts[1])
    if hour < 0 or hour > 23 or minute < 0 or minute > 59:
        raise ValueError("Jam tidak valid")
    return f"{hour:02d}:{minute:02d}"


# ============ ADMIN ============

class AdminCreate(BaseModel):
    nama: str
    email: EmailStr
    password: str
    foto_url: Optional[str] = None


class AdminUpdate(BaseModel):
    nama: Optional[str] = None
    email: Optional[EmailStr] = None
    password: Optional[str] = None
    foto_url: Optional[str] = None


class AdminResponse(BaseModel):
    id: int
    nama: str
    email: str
    foto_url: Optional[str] = None

    class Config:
        from_attributes = True


# ============ GURU ============

class GuruCreate(BaseModel):
    nama: str
    email: EmailStr
    password: str
    nip: str
    jenis_kelamin: Optional[str] = None
    foto_url: Optional[str] = None
    mapel_id: Optional[int] = None
    mapel_ids: Optional[list[int]] = None
    kelas_asuh_id: Optional[int] = None
    kelas_asuh_ids: Optional[list[int]] = None


class GuruUpdate(BaseModel):
    nama: Optional[str] = None
    email: Optional[EmailStr] = None
    nip: Optional[str] = None
    jenis_kelamin: Optional[str] = None
    password: Optional[str] = None
    foto_url: Optional[str] = None
    mapel_id: Optional[int] = None
    mapel_ids: Optional[list[int]] = None
    kelas_asuh_id: Optional[int] = None
    kelas_asuh_ids: Optional[list[int]] = None


class GuruProfileUpdate(BaseModel):
    nama: Optional[str] = None
    email: Optional[EmailStr] = None
    password: Optional[str] = None
    jenis_kelamin: Optional[str] = None
    foto_url: Optional[str] = None


class GuruResponse(BaseModel):
    id: int
    nama: str
    email: str
    nip: str
    jenis_kelamin: Optional[str] = None
    foto_url: Optional[str] = None
    mapel_id: Optional[int] = None
    mapel_ids: list[int] = Field(default_factory=list)
    kelas_asuh_id: Optional[int] = None
    kelas_asuh_ids: list[int] = Field(default_factory=list)

    class Config:
        from_attributes = True


# ============ SISWA ============

class SiswaCreate(BaseModel):
    nama: str
    nis: str
    jenis_kelamin: Optional[str] = None
    kelas_id: int
    alamat: Optional[str] = None
    foto_url: Optional[str] = None
    embedding_status: EmbeddingStatus = "belum_diproses"


class SiswaUpdate(BaseModel):
    nama: Optional[str] = None
    nis: Optional[str] = None
    jenis_kelamin: Optional[str] = None
    kelas_id: Optional[int] = None
    alamat: Optional[str] = None
    foto_url: Optional[str] = None
    embedding_status: Optional[EmbeddingStatus] = None


class SiswaResponse(BaseModel):
    id: int
    nama: str
    nis: str
    jenis_kelamin: Optional[str] = None
    kelas_id: int
    alamat: Optional[str] = None
    foto_url: Optional[str] = None
    embedding_status: EmbeddingStatus = "belum_diproses"

    class Config:
        from_attributes = True


# ============ KELAS ============

class KelasCreate(BaseModel):
    nama_kelas: str
    wali_kelas_id: Optional[int] = None


class KelasUpdate(BaseModel):
    nama_kelas: Optional[str] = None
    wali_kelas_id: Optional[int] = None


class KelasResponse(BaseModel):
    id: int
    nama_kelas: str
    wali_kelas_id: Optional[int] = None

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
    hari: ValidHari
    jam_mulai: str
    jam_selesai: str

    @field_validator("jam_mulai", "jam_selesai")
    @classmethod
    def normalize_time(cls, value: str) -> str:
        return _normalize_time(value)

    @model_validator(mode="after")
    def validate_time_range(self):
        if self.jam_mulai >= self.jam_selesai:
            raise ValueError("Jam mulai harus lebih awal dari jam selesai")
        return self


class JadwalBatchCreate(BaseModel):
    items: list[JadwalCreate] = Field(min_length=1)


class JadwalUpdate(BaseModel):
    kelas_id: Optional[int] = None
    mapel_id: Optional[int] = None
    guru_id: Optional[int] = None
    hari: Optional[ValidHari] = None
    jam_mulai: Optional[str] = None
    jam_selesai: Optional[str] = None

    @field_validator("jam_mulai", "jam_selesai")
    @classmethod
    def normalize_time(cls, value: Optional[str]) -> Optional[str]:
        if value is None:
            return None
        return _normalize_time(value)


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
    status: PresensiStatus
    tanggal: str
    jam_presensi: str


class PresensiUpdate(BaseModel):
    status: Optional[PresensiStatus] = None
    tanggal: Optional[str] = None
    jam_presensi: Optional[str] = None


class PresensiResponse(BaseModel):
    id: int
    siswa_id: int
    jadwal_id: int
    guru_id: int
    status: PresensiStatus
    tanggal: str
    jam_presensi: str

    class Config:
        from_attributes = True


# ============ EMBEDDING ============

class EmbeddingCreate(BaseModel):
    siswa_id: int
    embedding: list[float]


class EmbeddingUpdate(BaseModel):
    embedding: list[float]


class EmbeddingResponse(BaseModel):
    id: int
    siswa_id: int
    embedding: list[float]

    @field_validator("embedding", mode="before")
    @classmethod
    def parse_embedding(cls, value: Any) -> list[float]:
        if isinstance(value, str):
            return json.loads(value)
        return value

    class Config:
        from_attributes = True
