from fastapi import Depends, HTTPException, status
from fastapi.security import OAuth2PasswordBearer
from jose import jwt, JWTError
from core.config import SECRET_KEY, ALGORITHM

oauth2_scheme = OAuth2PasswordBearer(tokenUrl="auth/login")


def _unauthorized(detail: str = "Invalid token"):
    raise HTTPException(
        status_code=status.HTTP_401_UNAUTHORIZED,
        detail=detail,
        headers={"WWW-Authenticate": "Bearer"},
    )


def get_current_user(token: str = Depends(oauth2_scheme)):
    try:
        payload = jwt.decode(token, SECRET_KEY, algorithms=[ALGORITHM])
        user_id = payload.get("sub")
        role = payload.get("role")

        if user_id is None or role is None:
            _unauthorized()

        return {
            "id": int(user_id),
            "role": role,
        }

    except JWTError:
        _unauthorized("Token error")
    except (TypeError, ValueError):
        _unauthorized()


def require_admin(current_user: dict = Depends(get_current_user)):
    if current_user["role"] != "admin":
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Admin access required",
        )
    return current_user


def require_guru(current_user: dict = Depends(get_current_user)):
    if current_user["role"] != "guru":
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Guru access required",
        )
    return current_user
