import shutil
from pathlib import Path
from uuid import uuid4

from fastapi import APIRouter, Depends, File, HTTPException, UploadFile

from dependencies.auth import get_current_user

router = APIRouter(prefix="/uploads", tags=["Uploads"])

UPLOAD_ROOT = Path(__file__).resolve().parent.parent / "uploads"
ALLOWED_CATEGORIES = {"admin", "guru", "siswa"}
ALLOWED_EXTENSIONS = {".jpg", ".jpeg", ".png", ".webp"}


@router.post("/{category}")
def upload_photo(
    category: str,
    file: UploadFile = File(...),
    current_user: dict = Depends(get_current_user),
):
    if category not in ALLOWED_CATEGORIES:
        raise HTTPException(status_code=400, detail="Kategori upload tidak valid")
    if category in {"admin", "siswa"} and current_user["role"] != "admin":
        raise HTTPException(status_code=403, detail="Admin access required")

    suffix = Path(file.filename or "").suffix.lower()
    if suffix not in ALLOWED_EXTENSIONS:
        raise HTTPException(
            status_code=400,
            detail="Format foto harus JPG, PNG, atau WEBP",
        )

    target_dir = UPLOAD_ROOT / category
    target_dir.mkdir(parents=True, exist_ok=True)

    file_name = f"{category}_{uuid4().hex}{suffix}"
    target_path = target_dir / file_name

    try:
        with target_path.open("wb") as buffer:
            shutil.copyfileobj(file.file, buffer)
    finally:
        file.file.close()

    return {
        "foto_url": f"/uploads/{category}/{file_name}",
        "url": f"/uploads/{category}/{file_name}",
    }
