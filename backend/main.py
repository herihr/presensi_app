from pathlib import Path

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from fastapi.staticfiles import StaticFiles


from core.database import Base, engine, ensure_schema_updates
from core.env import load_env_file

load_env_file()

# 🔥 IMPORT SEMUA MODEL
from models import guru
from models import siswa
from models import admin
from models import kelas
from models import mata_pelajaran
from models import guru_mapel
from models import jadwal
from models import presensi
from models import embedding
from models import password_reset

# 🔥 BUAT TABEL OTOMATIS
Base.metadata.create_all(bind=engine)
ensure_schema_updates()

# 🔥 IMPORT ROUTERS
from routers import auth
from routers.admin_crud import router as admin_crud_router
from routers.guru_router import router as guru_router
from routers.siswa_router import router as siswa_router
from routers.kelas_router import router as kelas_router
from routers.mata_pelajaran_router import router as mata_pelajaran_router
from routers.jadwal_router import router as jadwal_router
from routers.presensi_router import router as presensi_crud_router
from routers.embedding_router import router as embedding_crud_router
from routers.upload_router import router as upload_router

app = FastAPI(title="Presensi Wajah API")
UPLOAD_DIR = Path(__file__).resolve().parent / "uploads"
UPLOAD_DIR.mkdir(parents=True, exist_ok=True)
for upload_category in ("admin", "guru", "siswa"):
    (UPLOAD_DIR / upload_category).mkdir(parents=True, exist_ok=True)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# 🔥 ROUTERS
app.include_router(auth.router, prefix="/auth", tags=["Auth"])

# 🔥 CRUD ROUTERS
app.include_router(admin_crud_router, prefix="/api")
app.include_router(guru_router, prefix="/api")
app.include_router(siswa_router, prefix="/api")
app.include_router(kelas_router, prefix="/api")
app.include_router(mata_pelajaran_router, prefix="/api")
app.include_router(jadwal_router, prefix="/api")
app.include_router(presensi_crud_router, prefix="/api")
app.include_router(embedding_crud_router, prefix="/api")
app.include_router(upload_router, prefix="/api")

app.mount("/uploads", StaticFiles(directory=str(UPLOAD_DIR)), name="uploads")


@app.get("/")
def root():
    return {"message": "API Running 🚀"}
