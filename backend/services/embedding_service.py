import json
from sqlalchemy.orm import Session
from models.embedding import Embedding
from models.siswa import Siswa
from models.siswa_kelas import SiswaKelas
from services.tahun_pelajaran_service import TahunPelajaranService


class EmbeddingService:

    # 🔹 CREATE EMBEDDING
    @staticmethod
    def create_embedding(db: Session, data):
        try:
            siswa = db.query(Siswa).filter(Siswa.id == data.siswa_id).first()
            if not siswa:
                raise ValueError("Siswa tidak ditemukan")

            emb = Embedding(
                siswa_id=data.siswa_id,
                embedding=json.dumps(data.embedding)
            )
            siswa.embedding_status = "diproses"
            db.add(emb)
            db.commit()
            db.refresh(emb)
            return emb
        except Exception:
            db.rollback()
            raise

    # 🔹 GET ALL EMBEDDINGS
    @staticmethod
    def get_all_embeddings(db: Session):
        return (
            db.query(Embedding)
            .join(Siswa, Embedding.siswa_id == Siswa.id)
            .filter(Embedding.siswa_id.isnot(None))
            .all()
        )

    # 🔹 GET EMBEDDING BY ID
    @staticmethod
    def get_embedding_by_id(db: Session, embedding_id: int):
        return (
            db.query(Embedding)
            .join(Siswa, Embedding.siswa_id == Siswa.id)
            .filter(
                Embedding.id == embedding_id,
                Embedding.siswa_id.isnot(None),
            )
            .first()
        )

    # 🔹 GET EMBEDDING BY SISWA
    @staticmethod
    def get_embedding_by_siswa(db: Session, siswa_id: int):
        return db.query(Embedding).filter(Embedding.siswa_id == siswa_id).all()

    # Ambil embedding hanya milik siswa aktif dalam kelas pada tahun pelajaran.
    @staticmethod
    def get_embedding_by_kelas(
        db: Session,
        kelas_id: int,
        tahun_pelajaran_id: int | None = None,
    ):
        tahun_id = tahun_pelajaran_id or TahunPelajaranService.get_active(db).id
        siswa_ids = [
            siswa_id
            for (siswa_id,) in (
                db.query(SiswaKelas.siswa_id)
                .filter(
                    SiswaKelas.kelas_id == kelas_id,
                    SiswaKelas.tahun_pelajaran_id == tahun_id,
                    SiswaKelas.status == "aktif",
                )
                .all()
            )
        ]
        if siswa_ids:
            return (
                db.query(Embedding)
                .filter(Embedding.siswa_id.in_(siswa_ids))
                .all()
            )

        # Kompatibilitas data lama yang belum tercatat pada siswa_kelas.
        return (
            db.query(Embedding)
            .join(Siswa, Siswa.id == Embedding.siswa_id)
            .filter(
                Siswa.kelas_id == kelas_id,
            )
            .all()
        )

    # 🔹 GET EMBEDDING BY SISWA (single)
    @staticmethod
    def get_embedding_by_siswa_single(db: Session, siswa_id: int):
        return db.query(Embedding).filter(Embedding.siswa_id == siswa_id).first()

    # 🔹 UPDATE EMBEDDING
    @staticmethod
    def update_embedding(db: Session, embedding_id: int, data):
        emb = db.query(Embedding).filter(Embedding.id == embedding_id).first()
        if not emb:
            return None

        if data.embedding:
            emb.embedding = json.dumps(data.embedding)

        db.commit()
        db.refresh(emb)
        return emb

    # 🔹 DELETE EMBEDDING
    @staticmethod
    def delete_embedding(db: Session, embedding_id: int):
        emb = db.query(Embedding).filter(Embedding.id == embedding_id).first()
        if not emb:
            return False

        db.delete(emb)
        db.commit()
        return True

    # 🔹 DELETE ALL EMBEDDINGS BY SISWA
    @staticmethod
    def delete_embedding_by_siswa(db: Session, siswa_id: int):
        emb = db.query(Embedding).filter(Embedding.siswa_id == siswa_id).all()
        if not emb:
            return False

        for e in emb:
            db.delete(e)
        db.commit()
        return True
