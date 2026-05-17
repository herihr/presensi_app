from pydantic import BaseModel, EmailStr

class LoginRequest(BaseModel):
    email: EmailStr
    password: str


class ForgotPasswordRequest(BaseModel):
    email: EmailStr
    role: str | None = None


class ResetPasswordRequest(BaseModel):
    email: EmailStr
    role: str | None = None
    code: str
    new_password: str


class UserResponse(BaseModel):
    id: int
    nama: str
    role: str
    is_wali: bool
    is_mapel: bool
