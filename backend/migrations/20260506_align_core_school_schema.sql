ALTER TABLE siswa
ADD COLUMN alamat VARCHAR(255) NULL,
ADD COLUMN foto_url VARCHAR(255) NULL,
ADD COLUMN embedding_status VARCHAR(30) NOT NULL DEFAULT 'belum_diproses';

ALTER TABLE guru
ADD COLUMN foto_url VARCHAR(255) NULL;

ALTER TABLE kelas
ADD UNIQUE INDEX uq_kelas_nama_kelas (nama_kelas),
ADD UNIQUE INDEX uq_kelas_wali_kelas_id (wali_kelas_id);

ALTER TABLE mata_pelajaran
ADD UNIQUE INDEX uq_mata_pelajaran_nama_mapel (nama_mapel);

ALTER TABLE guru_mapel
DROP INDEX uq_guru_mapel_guru,
ADD INDEX idx_guru_mapel_guru_id (guru_id),
ADD UNIQUE INDEX uq_guru_mapel_pair (guru_id, mapel_id);

ALTER TABLE presensi
ADD UNIQUE INDEX uq_presensi_siswa_jadwal_tanggal (siswa_id, jadwal_id, tanggal);
