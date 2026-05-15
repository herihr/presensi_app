from pydantic import BaseModel, EmailStr, Field


class GuruCreate(BaseModel):
    nama: str
    email: EmailStr
    password: str
    nip: str
    jenis_kelamin: str | None = None
    foto_url: str | None = None
    mapel_id: int | None = None
    mapel_ids: list[int] | None = None
    kelas_asuh_id: int | None = None
    kelas_asuh_ids: list[int] | None = None


class GuruUpdate(BaseModel):
    nama: str | None = None
    email: EmailStr | None = None
    password: str | None = None
    nip: str | None = None
    jenis_kelamin: str | None = None
    foto_url: str | None = None
    mapel_id: int | None = None
    mapel_ids: list[int] | None = None
    kelas_asuh_id: int | None = None
    kelas_asuh_ids: list[int] | None = None


class GuruResponse(BaseModel):
    id: int
    nama: str
    email: str
    nip: str
    jenis_kelamin: str | None = None
    foto_url: str | None = None
    mapel_id: int | None = None
    mapel_ids: list[int] = Field(default_factory=list)
    kelas_asuh_id: int | None = None
    kelas_asuh_ids: list[int] = Field(default_factory=list)

    class Config:
        from_attributes = True
