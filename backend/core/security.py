from passlib.context import CryptContext
from jose import jwt
from datetime import datetime, timedelta
from core.config import SECRET_KEY, ALGORITHM, ACCESS_TOKEN_EXPIRE_MINUTES
pwd_context = CryptContext(schemes=["bcrypt"], deprecated="auto")

def hash_password(password: str):
    # Truncate password to 72 bytes max (bcrypt limit)
    if len(password.encode('utf-8')) > 72:
        password = password[:72]
    return pwd_context.hash(password)

def verify_password(plain_password, hashed_password):
    # 🔥 FORCE CLEAN STRING
    plain_password = str(plain_password).strip()

    print("DEBUG PASSWORD:", repr(plain_password))
    print("LEN:", len(plain_password))
    print("BYTES:", len(plain_password.encode("utf-8")))

    if len(plain_password.encode('utf-8')) > 72:
        plain_password = plain_password[:72]

    return pwd_context.verify(plain_password, hashed_password)

def create_access_token(data: dict):
    to_encode = data.copy()
    expire = datetime.utcnow() + timedelta(minutes=ACCESS_TOKEN_EXPIRE_MINUTES)

    to_encode.update({"exp": expire})
    return jwt.encode(to_encode, SECRET_KEY, algorithm=ALGORITHM)