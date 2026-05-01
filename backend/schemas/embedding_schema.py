from pydantic import BaseModel
from typing import List

class EmbeddingCreate(BaseModel):
    siswa_id: int
    embedding: List[float]