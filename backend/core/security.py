import bcrypt
from jose import jwt
from datetime import datetime, timedelta
from core.config import SECRET_KEY, ALGORITHM, ACCESS_TOKEN_EXPIRE_MINUTES

BCRYPT_MAX_PASSWORD_BYTES = 72

def _password_bytes(password: str) -> bytes:
    password = str(password).strip()
    return password.encode("utf-8")[:BCRYPT_MAX_PASSWORD_BYTES]

def hash_password(password: str):
    return bcrypt.hashpw(_password_bytes(password), bcrypt.gensalt()).decode("utf-8")

def verify_password(plain_password, hashed_password):
    if not hashed_password:
        return False
    try:
        return bcrypt.checkpw(
            _password_bytes(plain_password),
            str(hashed_password).encode("utf-8"),
        )
    except (TypeError, ValueError):
        return False

def create_access_token(data: dict):
    to_encode = data.copy()
    expire = datetime.utcnow() + timedelta(minutes=ACCESS_TOKEN_EXPIRE_MINUTES)
    to_encode.update({"exp": expire})
    return jwt.encode(to_encode, SECRET_KEY, algorithm=ALGORITHM)