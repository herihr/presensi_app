from sqlalchemy import create_engine, inspect, text
from sqlalchemy.exc import SQLAlchemyError
from sqlalchemy.orm import sessionmaker, declarative_base

DATABASE_URL = "mysql+pymysql://root:@localhost/presensi_db"
engine = create_engine(DATABASE_URL)
SessionLocal = sessionmaker(
    bind=engine, 
    autoflush=False, 
    autocommit=False)
Base = declarative_base()


def ensure_schema_updates():
    inspector = inspect(engine)
    table_names = inspector.get_table_names()

    if "admin" in table_names:
        admin_columns = {column["name"] for column in inspector.get_columns("admin")}
        if "foto_url" not in admin_columns:
            with engine.begin() as connection:
                connection.execute(
                    text("ALTER TABLE admin ADD COLUMN foto_url LONGTEXT NULL")
                )
        else:
            with engine.begin() as connection:
                connection.execute(
                    text("ALTER TABLE admin MODIFY COLUMN foto_url LONGTEXT NULL")
                )

    if "guru" in table_names:
        guru_columns = {column["name"] for column in inspector.get_columns("guru")}
        if "jenis_kelamin" not in guru_columns:
            with engine.begin() as connection:
                connection.execute(
                    text("ALTER TABLE guru ADD COLUMN jenis_kelamin VARCHAR(20) NULL")
                )
        if "foto_url" not in guru_columns:
            with engine.begin() as connection:
                connection.execute(
                    text("ALTER TABLE guru ADD COLUMN foto_url LONGTEXT NULL")
                )
        else:
            with engine.begin() as connection:
                connection.execute(
                    text("ALTER TABLE guru MODIFY COLUMN foto_url LONGTEXT NULL")
                )

    if "siswa" in table_names:
        siswa_columns = {column["name"] for column in inspector.get_columns("siswa")}
        with engine.begin() as connection:
            if "jenis_kelamin" not in siswa_columns:
                connection.execute(
                    text("ALTER TABLE siswa ADD COLUMN jenis_kelamin VARCHAR(20) NULL")
                )
            if "alamat" not in siswa_columns:
                connection.execute(text("ALTER TABLE siswa ADD COLUMN alamat VARCHAR(255) NULL"))
            if "foto_url" not in siswa_columns:
                connection.execute(text("ALTER TABLE siswa ADD COLUMN foto_url VARCHAR(255) NULL"))
            if "embedding_status" not in siswa_columns:
                connection.execute(
                    text(
                        "ALTER TABLE siswa "
                        "ADD COLUMN embedding_status VARCHAR(30) NOT NULL DEFAULT 'belum_diproses'"
                    )
                )

    if "kelas" in table_names:
        _create_index_if_missing("kelas", "idx_kelas_wali_kelas_id", ["wali_kelas_id"])
        _create_unique_index_if_missing("kelas", "uq_kelas_wali_kelas_id", ["wali_kelas_id"])
        _create_unique_index_if_missing("kelas", "uq_kelas_nama_kelas", ["nama_kelas"])

    if "mata_pelajaran" in table_names:
        _create_unique_index_if_missing(
            "mata_pelajaran",
            "uq_mata_pelajaran_nama_mapel",
            ["nama_mapel"],
        )

    if "guru_mapel" in table_names:
        _create_index_if_missing("guru_mapel", "idx_guru_mapel_guru_id", ["guru_id"])
        _drop_single_column_unique_index("guru_mapel", "guru_id")
        _create_unique_index_if_missing(
            "guru_mapel",
            "uq_guru_mapel_pair",
            ["guru_id", "mapel_id"],
        )

    if "presensi" in table_names:
        _create_unique_index_if_missing(
            "presensi",
            "uq_presensi_siswa_jadwal_tanggal",
            ["siswa_id", "jadwal_id", "tanggal"],
        )

    if "jadwal" in table_names:
        try:
            with engine.begin() as connection:
                if "presensi" in table_names:
                    connection.execute(
                        text(
                            "DELETE p FROM presensi p "
                            "JOIN jadwal j ON j.id = p.jadwal_id "
                            "WHERE j.kelas_id IS NULL "
                            "OR j.mapel_id IS NULL "
                            "OR j.guru_id IS NULL"
                        )
                    )
                connection.execute(
                    text(
                        "DELETE FROM jadwal "
                        "WHERE kelas_id IS NULL OR mapel_id IS NULL OR guru_id IS NULL"
                    )
                )
        except SQLAlchemyError as exc:
            print(f"WARNING: could not clean invalid jadwal rows: {exc}")

    if "embeddings" in table_names:
        with engine.begin() as connection:
            connection.execute(
                text(
                    "DELETE e FROM embeddings e "
                    "LEFT JOIN siswa s ON s.id = e.siswa_id "
                    "WHERE e.siswa_id IS NULL OR s.id IS NULL"
                )
            )
            connection.execute(
                text("ALTER TABLE embeddings MODIFY COLUMN siswa_id INT NOT NULL")
            )


def _drop_single_column_unique_index(table_name: str, column_name: str):
    inspector = inspect(engine)
    indexes = inspector.get_indexes(table_name)

    for index in indexes:
        if index.get("unique") and index.get("column_names") == [column_name]:
            try:
                with engine.begin() as connection:
                    connection.execute(text(f"DROP INDEX {index['name']} ON {table_name}"))
            except SQLAlchemyError as exc:
                print(f"WARNING: could not drop unique index {index['name']}: {exc}")


def _create_unique_index_if_missing(table_name: str, index_name: str, column_names: list[str]):
    inspector = inspect(engine)
    indexes = inspector.get_indexes(table_name)
    existing = any(
        index.get("unique") and index.get("column_names") == column_names
        for index in indexes
    )

    if existing:
        return

    columns = ", ".join(column_names)
    try:
        with engine.begin() as connection:
            connection.execute(text(f"CREATE UNIQUE INDEX {index_name} ON {table_name} ({columns})"))
    except SQLAlchemyError as exc:
        print(f"WARNING: could not create unique index {index_name}: {exc}")


def _create_index_if_missing(table_name: str, index_name: str, column_names: list[str]):
    inspector = inspect(engine)
    indexes = inspector.get_indexes(table_name)
    existing = any(index.get("name") == index_name for index in indexes)

    if existing:
        return

    columns = ", ".join(column_names)
    try:
        with engine.begin() as connection:
            connection.execute(text(f"CREATE INDEX {index_name} ON {table_name} ({columns})"))
    except SQLAlchemyError as exc:
        print(f"WARNING: could not create index {index_name}: {exc}")

def get_db():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()
