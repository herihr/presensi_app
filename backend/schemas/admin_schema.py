from pydantic import BaseModel, EmailStr


class GuruCreate(BaseModel):
    nama: str
    email: EmailStr
    password: str
    nip: str


class GuruUpdate(BaseModel):
    nama: str
    email: EmailStr
    nip: str


class GuruResponse(BaseModel):
    id: int
    nama: str
    email: str
    nip: str

    class Config:
        from_attributes = True