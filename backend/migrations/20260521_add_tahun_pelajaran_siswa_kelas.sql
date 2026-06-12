CREATE TABLE IF NOT EXISTS tahun_pelajaran (
    id INT AUTO_INCREMENT PRIMARY KEY,
    nama VARCHAR(20) NOT NULL UNIQUE,
    tanggal_mulai DATE NULL,
    tanggal_selesai DATE NULL,
    is_aktif BOOLEAN NOT NULL DEFAULT FALSE
);

CREATE TABLE IF NOT EXISTS siswa_kelas (
    id INT AUTO_INCREMENT PRIMARY KEY,
    siswa_id INT NOT NULL,
    kelas_id INT NOT NULL,
    tahun_pelajaran_id INT NOT NULL,
    status VARCHAR(20) NOT NULL DEFAULT 'aktif',
    CONSTRAINT fk_siswa_kelas_siswa FOREIGN KEY (siswa_id) REFERENCES siswa(id),
    CONSTRAINT fk_siswa_kelas_kelas FOREIGN KEY (kelas_id) REFERENCES kelas(id),
    CONSTRAINT fk_siswa_kelas_tahun FOREIGN KEY (tahun_pelajaran_id) REFERENCES tahun_pelajaran(id),
    CONSTRAINT uq_siswa_kelas_siswa_tahun UNIQUE (siswa_id, tahun_pelajaran_id)
);

CREATE TABLE IF NOT EXISTS wali_kelas (
    id INT AUTO_INCREMENT PRIMARY KEY,
    guru_id INT NOT NULL,
    kelas_id INT NOT NULL,
    tahun_pelajaran_id INT NOT NULL,
    CONSTRAINT fk_wali_kelas_guru FOREIGN KEY (guru_id) REFERENCES guru(id),
    CONSTRAINT fk_wali_kelas_kelas FOREIGN KEY (kelas_id) REFERENCES kelas(id),
    CONSTRAINT fk_wali_kelas_tahun FOREIGN KEY (tahun_pelajaran_id) REFERENCES tahun_pelajaran(id),
    CONSTRAINT uq_wali_kelas_kelas_tahun UNIQUE (kelas_id, tahun_pelajaran_id),
    CONSTRAINT uq_wali_kelas_guru_tahun UNIQUE (guru_id, tahun_pelajaran_id)
);

ALTER TABLE jadwal ADD COLUMN tahun_pelajaran_id INT NULL;
CREATE INDEX idx_jadwal_tahun_pelajaran_id ON jadwal (tahun_pelajaran_id);
