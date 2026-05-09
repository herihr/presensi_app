import json
from sqlalchemy.orm import Session
from models.embedding import Embedding
from models.siswa import Siswa


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
        return db.query(Embedding).all()

    # 🔹 GET EMBEDDING BY ID
    @staticmethod
    def get_embedding_by_id(db: Session, embedding_id: int):
        return db.query(Embedding).filter(Embedding.id == embedding_id).first()

    # 🔹 GET EMBEDDING BY SISWA
    @staticmethod
    def get_embedding_by_siswa(db: Session, siswa_id: int):
        return db.query(Embedding).filter(Embedding.siswa_id == siswa_id).all()

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
