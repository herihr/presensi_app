from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware


from core.database import Base, engine

# 🔥 IMPORT SEMUA MODEL
from models import guru
from models import siswa
from models import admin
from models import kelas
from models import mata_pelajaran
from models import kelas_mapel
from models import guru_mapel
from models import jadwal
from models import presensi
from models import embedding

# 🔥 BUAT TABEL OTOMATIS
Base.metadata.create_all(bind=engine)

# 🔥 IMPORT ROUTERS
from routers import auth, presensi, embedding, admin
from routers.admin_crud import router as admin_crud_router
from routers.guru_router import router as guru_router
from routers.siswa_router import router as siswa_router
from routers.kelas_router import router as kelas_router
from routers.mata_pelajaran_router import router as mata_pelajaran_router
from routers.jadwal_router import router as jadwal_router
from routers.presensi_router import router as presensi_crud_router
from routers.embedding_router import router as embedding_crud_router

app = FastAPI(title="Presensi Wajah API")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# 🔥 ROUTERS
app.include_router(auth.router, prefix="/auth", tags=["Auth"])
app.include_router(presensi.router, prefix="/api/presensi", tags=["Presensi Face"])
app.include_router(embedding.router, prefix="/api/embedding", tags=["Embedding Face"])
app.include_router(admin.router, prefix="/api/admin", tags=["Admin Auth"])

# 🔥 CRUD ROUTERS
app.include_router(admin_crud_router, prefix="/api/admin", tags=["Admin CRUD"])
app.include_router(guru_router, prefix="/api/guru", tags=["Guru CRUD"])
app.include_router(siswa_router, prefix="/api/siswa", tags=["Siswa CRUD"])
app.include_router(kelas_router, prefix="/api/kelas", tags=["Kelas CRUD"])
app.include_router(mata_pelajaran_router, prefix="/api/mata-pelajaran", tags=["Mata Pelajaran CRUD"])
app.include_router(jadwal_router, prefix="/api/jadwal", tags=["Jadwal CRUD"])
app.include_router(presensi_crud_router, prefix="/api/presensi-crud", tags=["Presensi CRUD"])
app.include_router(embedding_crud_router, prefix="/api/embedding-crud", tags=["Embedding CRUD"])


@app.get("/")
def root():
    return {"message": "API Running 🚀"}
