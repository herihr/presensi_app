# Presensi App Backend API Contract

Base URL untuk endpoint aplikasi: `/api`

Auth berada di luar base API: `/auth`

Endpoint selain login membutuhkan header:

```txt
Authorization: Bearer <access_token>
```

## Auth

`POST /auth/login`

Request:

```json
{
  "email": "admin@gmail.com",
  "password": "123456"
}
```

Response:

```json
{
  "access_token": "...",
  "token_type": "bearer",
  "user": {
    "id": 1,
    "nama": "Admin",
    "email": "admin@gmail.com",
    "foto_url": "/uploads/admin/admin_xxx.jpg",
    "role": "admin",
    "is_wali": false,
    "is_mapel": false
  }
}
```

`POST /auth/forgot-password`

Request:

```json
{
  "email": "guru@gmail.com",
  "role": "guru"
}
```

Response:

```json
{
  "message": "Kode reset password sudah dibuat",
  "email_sent": true,
  "expires_in_minutes": 10
}
```

`role` dapat berisi `guru` atau `admin`. Kode reset dikirim melalui SMTP.
Konfigurasi SMTP dibaca dari environment: `SMTP_HOST`, `SMTP_PORT`,
`SMTP_USER`, `SMTP_PASSWORD`, `SMTP_FROM`, dan `SMTP_TLS`.

`POST /auth/reset-password`

Request:

```json
{
  "email": "guru@gmail.com",
  "role": "guru",
  "code": "123456",
  "new_password": "password-baru"
}
```

Response:

```json
{
  "message": "Password berhasil direset"
}
```

## Resource Endpoints

Gunakan trailing slash untuk collection endpoint agar tidak kena redirect FastAPI.

Operasi tulis master data (`POST`, `PUT`, `DELETE`) membutuhkan role `admin`.
Operasi baca membutuhkan user yang sudah login. Untuk alur presensi, aturan yang
lebih spesifik seperti guru mapel dan wali kelas akan dipasang di kontrak bisnis
berikutnya.

| Resource | Collection | Detail | Filter |
| --- | --- | --- | --- |
| Admin | `/api/admin/` | `/api/admin/{admin_id}` | - |
| Guru | `/api/guru/` | `/api/guru/{guru_id}` | `/api/guru/mapel/{mapel_id}` |
| Siswa | `/api/siswa/` | `/api/siswa/{siswa_id}` | `/api/siswa/kelas/{kelas_id}` |
| Kelas | `/api/kelas/` | `/api/kelas/{kelas_id}` | - |
| Mata Pelajaran | `/api/mata-pelajaran/` | `/api/mata-pelajaran/{mapel_id}` | - |
| Jadwal | `/api/jadwal/`, `/api/jadwal/batch` | `/api/jadwal/{jadwal_id}` | `/api/jadwal/kelas/{kelas_id}`, `/api/jadwal/guru/{guru_id}`, `/api/jadwal/mapel/{mapel_id}`, `/api/jadwal/hari/{kelas_id}/{hari}` |
| Presensi | `/api/presensi/` | `/api/presensi/{presensi_id}` | `/api/presensi/siswa/{siswa_id}`, `/api/presensi/jadwal/{jadwal_id}`, `/api/presensi/guru/{guru_id}`, `/api/presensi/tanggal/{tanggal}` |
| Embedding | `/api/embedding/` | `/api/embedding/{embedding_id}` | `/api/embedding/siswa/{siswa_id}` |
| Upload Foto | `/api/uploads/{category}` | - | `category`: `admin`, `guru`, atau `siswa` |

Collection endpoint mendukung:

- `POST` untuk create
- `GET` untuk list

Detail endpoint mendukung:

- `GET` untuk detail
- `PUT` untuk update
- `DELETE` untuk delete

## Payload Utama

`AdminUpdate`

```json
{
  "nama": "Admin Sekolah",
  "email": "admin@gmail.com",
  "password": "password-baru",
  "foto_url": "/uploads/admin/admin_xxx.jpg"
}
```

`password` dan `foto_url` opsional. Jika `password` tidak dikirim, password lama
tetap dipakai.

`GuruCreate`

```json
{
  "nama": "Guru 1",
  "email": "guru@gmail.com",
  "password": "123456",
  "nip": "123456789",
  "jenis_kelamin": "Laki-laki",
  "foto_url": "/uploads/guru/guru_xxx.jpg",
  "mapel_ids": [1, 2],
  "kelas_asuh_id": 1
}
```

`jenis_kelamin` berisi `Laki-laki` atau `Perempuan`. `foto_url` menyimpan path
file di server agar foto bisa tampil di semua perangkat guru/admin yang login.
`jenis_kelamin`, `foto_url`, `mapel_ids`, dan `kelas_asuh_id` bersifat opsional.
Backend masih menerima `mapel_id` untuk kompatibilitas form lama. Format mapel
yang disarankan adalah `mapel_ids` karena satu guru bisa
mengajar lebih dari satu mata pelajaran. Untuk wali kelas, satu guru hanya boleh
dipilih sebagai wali untuk satu kelas dari form tambah guru.

`SiswaCreate`

```json
{
  "nama": "Siswa 1",
  "nis": "2026001",
  "jenis_kelamin": "Perempuan",
  "kelas_id": 1,
  "alamat": "Jl. Sekolah No. 1",
  "foto_url": "/uploads/siswa/siswa_xxx.jpg",
  "embedding_status": "belum_diproses"
}
```

`nis` harus unik. `jenis_kelamin` berisi `Laki-laki` atau `Perempuan`.
`embedding_status` hanya boleh `belum_diproses`, `diproses`, atau `gagal`.

## Upload Foto Profil

`POST /api/uploads/{category}`

Header:

```txt
Authorization: Bearer <access_token>
Content-Type: multipart/form-data
```

Form data:

```txt
file: <image jpg/png/webp>
```

Response:

```json
{
  "foto_url": "/uploads/siswa/siswa_xxx.jpg",
  "url": "/uploads/siswa/siswa_xxx.jpg"
}
```

File fisik disimpan oleh backend di folder `backend/uploads/{category}`.
Database hanya menyimpan path server pada kolom `foto_url`.

`KelasCreate`

```json
{
  "nama_kelas": "X IPA 1",
  "wali_kelas_id": 1
}
```

`nama_kelas` harus unik. `wali_kelas_id` opsional dan harus mengarah ke guru yang
valid jika diisi. Satu guru boleh menjadi wali untuk lebih dari satu kelas.

`MataPelajaranCreate`

```json
{
  "nama_mapel": "Matematika"
}
```

`nama_mapel` harus unik.

`JadwalCreate`

```json
{
  "kelas_id": 1,
  "mapel_id": 1,
  "guru_id": 1,
  "hari": "Senin",
  "jam_mulai": "07:00",
  "jam_selesai": "08:30"
}
```

`hari` hanya boleh `Senin`, `Selasa`, `Rabu`, `Kamis`, `Jumat`, `Sabtu`, atau
`Minggu`. Jam memakai format `HH:MM`; backend juga menerima input `HH.MM` lalu
menormalisasi ke `HH:MM`. `jam_mulai` harus lebih awal dari `jam_selesai`.

Validasi jadwal:

- `kelas_id`, `guru_id`, dan `mapel_id` harus valid.
- Guru harus sudah terhubung ke mata pelajaran lewat data guru-mapel.
- Jadwal guru tidak boleh bentrok pada hari dan rentang jam yang sama.
- Jadwal kelas tidak boleh bentrok pada hari dan rentang jam yang sama.

`JadwalBatchCreate`

Endpoint: `POST /api/jadwal/batch`

```json
{
  "items": [
    {
      "kelas_id": 1,
      "mapel_id": 1,
      "guru_id": 2,
      "hari": "Senin",
      "jam_mulai": "07:00",
      "jam_selesai": "08:20"
    }
  ]
}
```

Dipakai saat admin menyusun beberapa jadwal dalam satu hari. Semua item disimpan
dalam satu transaksi; jika salah satu item tidak valid atau bentrok, seluruh
batch ditolak.

`PresensiCreate`

```json
{
  "siswa_id": 1,
  "jadwal_id": 1,
  "guru_id": 1,
  "status": "hadir",
  "tanggal": "2026-05-02",
  "jam_presensi": "07:15"
}
```

`status` hanya boleh `hadir`, `izin`, `sakit`, atau `alpha`. Backend memastikan
siswa berada di kelas jadwal tersebut, guru sesuai dengan guru pada jadwal, dan
tidak ada presensi dobel untuk kombinasi `siswa_id`, `jadwal_id`, dan `tanggal`.

`EmbeddingCreate`

```json
{
  "siswa_id": 1,
  "embedding": [0.12, 0.34, 0.56]
}
```

Embedding disimpan sebagai JSON string di database, tetapi kontrak API selalu memakai `list[float]`.
