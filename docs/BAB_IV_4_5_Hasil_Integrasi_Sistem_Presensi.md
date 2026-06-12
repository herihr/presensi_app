# 4.5 Hasil Integrasi Sistem Presensi

Integrasi sistem presensi dilakukan dengan menghubungkan aplikasi mobile, layanan REST API, backend pengolahan data dan deteksi wajah, model pengenalan wajah, serta basis data menjadi satu alur kerja yang terpadu. Hasil implementasi menunjukkan bahwa guru dapat masuk ke dalam aplikasi, memilih jadwal mengajar, membuka halaman detail mata pelajaran, dan menjalankan kamera presensi. Frame terpilih dari kamera kemudian dikirimkan ke backend untuk proses deteksi wajah menggunakan model YOLO. Koordinat wajah hasil deteksi dikembalikan ke aplikasi mobile untuk digunakan dalam proses pemotongan wajah, ekstraksi embedding menggunakan MobileFaceNet, dan pencocokan identitas menggunakan cosine similarity.

Apabila wajah berhasil dikenali dan memenuhi nilai ambang pengenalan, aplikasi mengubah status siswa menjadi hadir serta mengirimkan data presensi ke backend. Backend selanjutnya melakukan validasi terhadap siswa, jadwal, guru, kelas, dan kemungkinan duplikasi sebelum menyimpan data ke dalam basis data MariaDB. Data yang telah tersimpan dapat dimuat kembali pada halaman detail mata pelajaran dan ditampilkan pada halaman rekap kehadiran. Dengan demikian, hasil integrasi tidak hanya menampilkan identitas siswa pada kamera, tetapi juga menghasilkan catatan presensi yang tersimpan secara persisten.

Arsitektur implementasi yang ditemukan pada kode bersifat hibrida. Model YOLO untuk deteksi wajah dijalankan pada backend, sedangkan MobileFaceNet dan cosine similarity dijalankan pada perangkat mobile melalui isolate. Pembagian proses tersebut memungkinkan layanan backend menangani deteksi wajah, sementara aplikasi mobile tetap mengelola pengenalan identitas dan antarmuka pengguna.

## 4.5.1 Hasil Integrasi Arsitektur Sistem

Aplikasi mobile dikembangkan menggunakan Flutter dan bahasa pemrograman Dart. Flutter digunakan untuk membangun antarmuka pengguna, mengakses kamera, menampilkan hasil deteksi, dan berkomunikasi dengan backend. Aplikasi memanfaatkan paket `camera` untuk memperoleh image stream, paket `http` untuk pertukaran data melalui REST API, paket `image` untuk pengolahan citra, serta `tflite_flutter` untuk menjalankan MobileFaceNet pada perangkat mobile.

Backend dikembangkan menggunakan Python dan framework FastAPI. FastAPI berfungsi sebagai layanan API yang menerima permintaan dari aplikasi mobile, menjalankan deteksi wajah pada server, memvalidasi data, serta mengelola operasi basis data. SQLAlchemy digunakan sebagai Object Relational Mapper (ORM), sedangkan PyMySQL digunakan sebagai driver koneksi antara backend dan MariaDB. Backend dijalankan melalui server aplikasi Uvicorn.

Komunikasi antara aplikasi mobile dan backend menggunakan REST API melalui protokol HTTP atau HTTPS. Berdasarkan konfigurasi aplikasi, koneksi dapat diarahkan melalui domain Cloudflared `https://api.presensatu.my.id` atau alamat IP lokal `http://192.168.1.11:8000`. Aplikasi juga memiliki mekanisme fallback untuk mencoba sumber backend lainnya apabila sumber utama tidak dapat dijangkau. Setelah proses login berhasil, token JWT dikirimkan pada header `Authorization` dengan skema Bearer untuk mengakses endpoint yang terlindungi.

Pada proses presensi, aplikasi tidak memproses seluruh area tampilan kamera. Area pemindaian berbentuk kotak berwarna biru dipetakan terhadap koordinat frame kamera, kemudian hanya bagian frame pada area tersebut yang digunakan untuk proses AI. Citra area pemindaian dikodekan menjadi JPEG dan dikirimkan ke endpoint deteksi wajah pada backend. Backend menjalankan model YOLO berformat TensorFlow Lite untuk memperoleh koordinat bounding box wajah. Model tersebut dirujuk oleh kode sebagai model deteksi wajah YOLO, sedangkan kepastian bahwa model yang digunakan merupakan varian YOLO11n perlu didukung dengan metadata ekspor model.

Backend mengembalikan koordinat bounding box, ukuran citra, confidence, dan informasi waktu proses dalam bentuk JSON. Aplikasi mobile kemudian memotong wajah berdasarkan koordinat tersebut dengan tambahan padding, menjalankan MobileFaceNet, dan membandingkan embedding hasil pengenalan terhadap embedding siswa yang diperoleh dari basis data. Proses MobileFaceNet dan cosine similarity dilakukan pada isolate terpisah agar proses utama antarmuka tidak dibebani oleh inferensi AI.

MariaDB digunakan untuk menyimpan data pengguna, siswa, guru, kelas, mata pelajaran, jadwal, embedding wajah, dan hasil presensi. Relasi data menyebabkan hasil pengenalan wajah dapat dikaitkan dengan siswa yang tepat, sedangkan hasil presensi dapat dikaitkan dengan jadwal, guru, kelas, mata pelajaran, dan tanggal pelaksanaan.

Komponen integrasi sistem dapat dilihat pada Tabel 4.x.

**Tabel 4.x Komponen integrasi sistem presensi**

| Komponen | Fungsi | Hasil Integrasi |
|---|---|---|
| Aplikasi mobile Flutter | Menyediakan antarmuka login, dashboard, jadwal, daftar siswa, kamera presensi, dan rekap | Guru dapat menjalankan seluruh alur presensi melalui perangkat mobile |
| Camera image stream | Menghasilkan frame kamera untuk proses presensi | Frame dapat diperoleh secara kontinu tanpa mengambil foto secara manual |
| Area pemindaian | Membatasi area frame yang dikirim untuk deteksi | Wajah di luar kotak pemindaian tidak diproses sebagai objek presensi |
| REST API | Menjadi media pertukaran data antara aplikasi dan backend | Data jadwal, siswa, embedding, hasil deteksi, dan presensi dapat dipertukarkan |
| Cloudflared/domain | Menyediakan akses HTTPS menuju backend | Aplikasi dapat mengakses backend melalui `https://api.presensatu.my.id` |
| IP lokal | Menyediakan akses backend pada jaringan lokal | Aplikasi dapat menggunakan `http://192.168.1.11:8000` sebagai sumber alternatif |
| FastAPI | Menyediakan endpoint, validasi, autentikasi, dan layanan pengolahan data | Permintaan aplikasi dapat diproses dan menghasilkan respons terstruktur |
| YOLO pada backend | Mendeteksi satu atau beberapa wajah dan menghasilkan bounding box | Koordinat wajah dikembalikan ke aplikasi dalam bentuk JSON |
| MobileFaceNet pada aplikasi mobile | Mengekstraksi ciri wajah menjadi embedding | Setiap wajah hasil deteksi dapat direpresentasikan sebagai vektor embedding |
| Cosine similarity pada aplikasi mobile | Membandingkan embedding wajah kamera dengan embedding siswa | Sistem memperoleh identitas dengan skor kemiripan tertinggi |
| Dart isolate | Menjalankan konversi frame, komunikasi deteksi, embedding, dan pencocokan di luar isolate UI | Antarmuka dan preview kamera tidak diblokir langsung oleh proses AI |
| SQLAlchemy dan PyMySQL | Menghubungkan objek backend dengan tabel MariaDB | Validasi dan operasi data dapat dilakukan melalui model backend |
| MariaDB | Menyimpan data master, embedding, jadwal, dan hasil presensi | Data presensi tersimpan dan dapat ditampilkan kembali |

Berdasarkan Tabel 4.x, setiap komponen memiliki tanggung jawab yang berbeda tetapi saling terhubung. Aplikasi mobile berperan sebagai media interaksi dan lokasi pengenalan identitas, backend berperan sebagai penyedia API, detektor wajah, dan pengelola validasi, sedangkan MariaDB menjadi penyimpanan permanen. Pembagian tersebut membentuk satu alur mulai dari pemilihan jadwal hingga pencatatan presensi.

Diagram arsitektur disarankan ditempatkan setelah pembahasan Tabel 4.x dengan alur berikut:

`Aplikasi Flutter → REST API melalui Cloudflared/IP lokal → FastAPI → YOLO → respons bounding box → isolate aplikasi mobile → crop wajah → MobileFaceNet → cosine similarity → REST API presensi → MariaDB`.

**Gambar 4.x Diagram arsitektur integrasi sistem presensi**

Berdasarkan Gambar 4.x, hasil deteksi YOLO tidak langsung menjadi hasil presensi. Bounding box dari server masih diproses pada aplikasi mobile untuk pengenalan identitas. Setelah identitas memenuhi ambang pengenalan, barulah aplikasi mengirimkan catatan presensi ke backend untuk divalidasi dan disimpan.

## 4.5.2 Hasil Integrasi API dan Pertukaran Data

Integrasi aplikasi mobile dan backend dilakukan melalui REST API. Setiap permintaan dikirim menggunakan method HTTP sesuai kebutuhan, yaitu `GET` untuk memperoleh data dan `POST` untuk mengirim atau membuat data. Aplikasi juga mendukung `PUT` dan `DELETE` untuk fungsi administrasi. Data terstruktur umumnya dikirim dan diterima dalam format JSON, sedangkan citra untuk deteksi wajah dikirim sebagai multipart request.

Pada awal penggunaan, aplikasi mengirimkan email dan password melalui endpoint login. Setelah data pengguna diverifikasi, backend mengembalikan access token dan informasi pengguna. Token tersebut disimpan oleh aplikasi dan disertakan dalam permintaan berikutnya. Mekanisme ini memastikan endpoint yang memerlukan autentikasi hanya dapat diakses oleh pengguna yang telah login.

Ketika guru membuka dashboard, aplikasi mengambil data jadwal berdasarkan ID guru. Saat salah satu jadwal dipilih, aplikasi mengambil daftar siswa aktif berdasarkan kelas serta data presensi pada tanggal yang sedang dipilih. Sebelum kamera presensi dijalankan, aplikasi mengambil embedding hanya untuk siswa dalam kelas yang sedang dipresensi. Apabila presensi dijalankan untuk satu siswa, aplikasi hanya mengambil embedding milik siswa tersebut. Pembatasan ini mencegah seluruh embedding siswa pada basis data dimuat tanpa kebutuhan.

Pada proses kamera, aplikasi mengirimkan citra JPEG dari area pemindaian ke endpoint `/api/ai/detect-faces`. Permintaan tersebut juga membawa confidence threshold dan IoU threshold. Backend menjalankan YOLO dan mengembalikan ukuran citra beserta daftar bounding box. Koordinat tersebut digunakan oleh aplikasi untuk memotong wajah dan melakukan pengenalan. Setelah seorang siswa dikenali, aplikasi mengirimkan identitas siswa, jadwal, guru, status, tanggal, dan jam presensi melalui endpoint `/api/presensi/`.

Backend mengembalikan kode status HTTP dan data respons untuk menunjukkan keberhasilan atau kegagalan. Respons pada rentang kode 2xx diperlakukan sebagai proses berhasil. Kegagalan validasi dapat dikembalikan dengan kode 400, kegagalan autentikasi dengan kode 401, pembatasan hak akses dengan kode 403, data yang tidak ditemukan dengan kode 404, dan ketidaktersediaan layanan AI dengan kode 503. Pesan kesalahan tersebut kemudian ditampilkan oleh aplikasi dalam bentuk pemberitahuan kepada pengguna.

Struktur endpoint API yang menjadi bagian utama integrasi presensi dapat dilihat pada Tabel 4.x.

**Tabel 4.x Endpoint API utama pada integrasi sistem presensi**

| Endpoint | Method | Fungsi | Data yang Dikirim/Diterima |
|---|---|---|---|
| `/auth/login` | POST | Melakukan autentikasi admin atau guru | Mengirim email dan password; menerima access token, tipe token, role, serta data pengguna |
| `/api/jadwal/guru/{guru_id}` | GET | Mengambil jadwal mengajar milik guru | Menerima daftar jadwal guru |
| `/api/jadwal/kelas/{kelas_id}` | GET | Mengambil jadwal berdasarkan kelas | Menerima daftar jadwal kelas untuk kebutuhan detail dan rekap |
| `/api/siswa/kelas/{kelas_id}` | GET | Mengambil siswa aktif pada kelas | Menerima daftar siswa beserta identitas dan data pendukung |
| `/api/embedding/kelas/{kelas_id}` | GET | Mengambil embedding siswa pada kelas yang dipresensi | Menerima embedding yang terkait dengan siswa aktif dalam kelas |
| `/api/embedding/siswa/{siswa_id}` | GET | Mengambil embedding untuk presensi satu siswa | Menerima embedding milik siswa tertentu |
| `/api/ai/detect-faces` | POST multipart | Mengirim citra area pemindaian untuk deteksi wajah oleh YOLO | Mengirim JPEG, confidence threshold, dan IoU threshold; menerima bounding box dan waktu proses |
| `/api/presensi/` | POST | Menyimpan hasil presensi siswa | Mengirim siswa, jadwal, guru, status, tanggal, dan jam presensi |
| `/api/presensi/tanggal/{tanggal}` | GET | Mengambil data presensi berdasarkan tanggal | Menerima catatan presensi pada tanggal tertentu |
| `/api/presensi/jadwal/{jadwal_id}` | GET | Mengambil data presensi berdasarkan jadwal | Menerima catatan presensi untuk jadwal tertentu |
| `/api/kelas/` | GET | Mengambil data kelas | Menerima daftar kelas untuk tampilan dan penyusunan rekap |
| `/api/mata-pelajaran/` | GET | Mengambil data mata pelajaran | Menerima daftar mata pelajaran untuk tampilan jadwal dan rekap |

Berdasarkan Tabel 4.x, integrasi tidak bergantung pada satu endpoint tunggal. Aplikasi menggabungkan data dari endpoint jadwal, siswa, embedding, presensi, kelas, dan mata pelajaran untuk membentuk informasi yang ditampilkan kepada guru. Khusus rekap kehadiran, aplikasi menyusun hasil rekap dari beberapa endpoint, bukan dari satu endpoint rekap khusus.

Respons endpoint deteksi wajah menggunakan struktur yang dapat dilihat pada Tabel 4.x.

**Tabel 4.x Struktur respons deteksi wajah**

| Field | Bentuk Data | Keterangan |
|---|---|---|
| `image_width` | Integer | Lebar citra area pemindaian yang diterima backend |
| `image_height` | Integer | Tinggi citra area pemindaian yang diterima backend |
| `candidates` | Integer | Jumlah kandidat deteksi sebelum hasil akhir |
| `boxes` | Array | Daftar bounding box wajah hasil deteksi dan NMS |
| `boxes[].left` | Number | Posisi sisi kiri bounding box |
| `boxes[].top` | Number | Posisi sisi atas bounding box |
| `boxes[].width` | Number | Lebar bounding box |
| `boxes[].height` | Number | Tinggi bounding box |
| `boxes[].confidence` | Number | Tingkat keyakinan hasil deteksi wajah |
| `timings` | Object | Informasi waktu proses deteksi pada backend |

Berdasarkan Tabel 4.x, backend tidak mengembalikan identitas siswa. Backend hanya menghasilkan lokasi wajah dan confidence deteksi. Identitas ditentukan oleh aplikasi mobile setelah wajah dipotong dan dibandingkan dengan embedding siswa.

Struktur data yang dikirim untuk menyimpan hasil presensi dapat dilihat pada Tabel 4.x.

**Tabel 4.x Struktur request penyimpanan presensi**

| Field | Bentuk Data | Keterangan |
|---|---|---|
| `siswa_id` | Integer | ID siswa yang berhasil dikenali |
| `jadwal_id` | Integer | ID jadwal yang sedang dipresensi |
| `guru_id` | Integer | ID guru yang menjalankan presensi |
| `status` | String | Status presensi; pengenalan otomatis mengirim status `hadir` |
| `tanggal` | String | Tanggal pelaksanaan presensi |
| `jam_presensi` | String | Jam ketika presensi dicatat |

Berdasarkan Tabel 4.x, data hasil pengenalan dikaitkan langsung dengan konteks akademik saat presensi dilakukan. Dengan demikian, satu hasil pengenalan tidak hanya menyimpan identitas siswa, tetapi juga jadwal, guru, tanggal, jam, dan status kehadiran.

Parameter integrasi AI yang ditemukan pada kode dapat dilihat pada Tabel 4.x.

**Tabel 4.x Parameter integrasi proses deteksi dan pengenalan wajah**

| Parameter | Nilai | Fungsi |
|---|---:|---|
| Target frame proses AI | 1 frame per detik | Membatasi jumlah frame yang dikirim dan diproses agar tidak menumpuk |
| Waktu stabilisasi kamera | 3 detik | Melewati frame awal agar kamera memperoleh kondisi yang lebih stabil |
| Confidence threshold YOLO realtime | 0,50 | Menyaring kandidat deteksi wajah berdasarkan confidence |
| IoU threshold NMS realtime | 0,50 | Menghilangkan bounding box yang saling tumpang tindih secara berlebihan |
| Padding crop wajah | 0,25 atau 25% | Menambahkan area di sekitar bounding box sebelum wajah dipotong |
| Jumlah maksimum bounding box backend | 8 | Membatasi jumlah hasil deteksi wajah pada satu citra |
| Kualitas JPEG permintaan deteksi | 85 | Mengatur kualitas citra area pemindaian yang dikirim ke backend |
| Minimum ukuran wajah untuk pengenalan | 50 piksel | Mencegah wajah yang terlalu kecil dilanjutkan ke tahap pengenalan |
| Ukuran input MobileFaceNet | 112 × 112 × 3 | Menyesuaikan crop wajah dengan tensor input MobileFaceNet |
| Normalisasi piksel MobileFaceNet | `(nilai piksel - 127,5) / 128,0` | Mengubah rentang nilai piksel sebelum inferensi |
| Dimensi embedding MobileFaceNet | 192 | Menyatakan jumlah elemen pada vektor ciri wajah |
| Normalisasi embedding | L2 normalization | Menormalisasi panjang vektor embedding |
| Similarity threshold | 0,65 | Menentukan batas minimum agar wajah dianggap dikenali |
| Metode pencocokan | Cosine similarity | Mengukur kemiripan embedding wajah kamera dengan embedding basis data |
| MobileFaceNet interpreter threads | 2 | Mengatur jumlah thread interpreter TFLite pada perangkat |
| Proses latar belakang mobile | Dart isolate | Menjalankan proses AI tanpa memblokir isolate antarmuka |
| Ukuran input tensor YOLO | **[PERLU DIISI: hasil pemeriksaan `get_input_details()` model YOLO11n yang digunakan]** | Menentukan ukuran citra masukan model deteksi |
| Bentuk output tensor YOLO | **[PERLU DIISI: hasil pemeriksaan `get_output_details()` model YOLO11n yang digunakan]** | Menentukan format keluaran prediksi model |

Berdasarkan Tabel 4.x, proses integrasi menggunakan parameter yang mengatur keseimbangan antara beban komputasi, kualitas deteksi, dan keputusan pengenalan. Confidence threshold dan IoU threshold digunakan pada tahap deteksi, sedangkan similarity threshold digunakan pada tahap pengenalan. Ketiga parameter tersebut memiliki fungsi yang berbeda dan tidak dapat dipertukarkan.

## 4.5.3 Hasil Integrasi Aplikasi Mobile

Hasil integrasi aplikasi mobile ditunjukkan melalui rangkaian halaman yang mendukung alur kerja guru. Halaman login menjadi titik awal akses sistem. Pengguna dapat memilih role guru atau admin, kemudian memasukkan email dan password. Setelah backend memverifikasi kredensial, aplikasi menerima token dan mengarahkan pengguna menuju halaman yang sesuai dengan role. Untuk pengguna guru, aplikasi menampilkan dashboard yang berisi identitas guru, ringkasan kehadiran kelas wali, dan jadwal mengajar pada hari yang sedang berjalan.

**Gambar 4.x Tampilan halaman login aplikasi**

Gambar tersebut disarankan ditempatkan setelah paragraf penjelasan login. Berdasarkan Gambar 4.x, halaman login berfungsi sebagai penghubung pertama antara pengguna dan layanan autentikasi backend sebelum fitur presensi dapat digunakan.

Pada dashboard guru, jadwal ditampilkan berdasarkan ID guru dan hari berjalan. Guru dapat memilih salah satu card jadwal untuk membuka halaman detail mata pelajaran. Halaman detail memuat nama mata pelajaran, kelas, daftar siswa, foto profil, NIS, serta status kehadiran siswa. Status yang telah tersimpan pada basis data tetap dapat dimuat kembali ketika halaman dibuka ulang atau setelah pengguna login kembali.

**Gambar 4.x Tampilan dashboard guru dan jadwal mengajar**

**Gambar 4.x Tampilan detail mata pelajaran dan daftar siswa**

Kedua gambar tersebut disarankan ditempatkan setelah penjelasan dashboard dan halaman detail. Berdasarkan Gambar 4.x, jadwal menjadi konteks utama presensi karena menentukan kelas, mata pelajaran, guru, dan waktu pelaksanaan. Halaman detail mata pelajaran selanjutnya menjadi penghubung antara jadwal dengan daftar siswa yang akan dipresensi.

Guru dapat menjalankan presensi untuk seluruh siswa melalui tombol presensi bersama atau menjalankan presensi untuk seorang siswa melalui tombol pada card siswa. Pada presensi seluruh siswa, aplikasi hanya memuat embedding siswa aktif dalam kelas tersebut. Pada presensi individual, aplikasi hanya memuat embedding siswa yang dipilih. Setelah tombol presensi ditekan, aplikasi membuka kamera dan menampilkan area pemindaian berwarna biru.

Selama tiga detik awal, frame kamera tidak diproses agar kamera memperoleh pencahayaan dan fokus yang lebih stabil. Setelah waktu stabilisasi selesai, aplikasi membatasi proses AI hingga satu frame per detik dan melewati frame lain ketika worker masih sibuk. Area di dalam kotak pemindaian dipetakan ke frame kamera, dikirim ke server YOLO, lalu hasil bounding box dikembalikan ke aplikasi. Apabila beberapa wajah berada di dalam area pemindaian, setiap bounding box diproses secara terpisah sehingga sistem mendukung multi-face detection.

Pada aplikasi, bounding box hasil pengenalan ditampilkan dengan label nama siswa dan skor kemiripan. Wajah yang terdeteksi tetapi tidak memenuhi threshold ditampilkan sebagai tidak dikenali. Apabila skor terbaik memenuhi threshold 0,65 dan ukuran wajah memenuhi batas minimum, ID siswa dilaporkan sebagai hasil pengenalan. Siswa yang sama hanya dilaporkan satu kali pada satu sesi kamera untuk mencegah pengiriman presensi berulang.

**Gambar 4.x Tampilan kamera presensi multi-wajah**

Gambar tersebut disarankan ditempatkan setelah penjelasan proses kamera. Berdasarkan Gambar 4.x, hasil integrasi AI ditunjukkan melalui area pemindaian, bounding box wajah, label identitas, dan confidence pengenalan yang tampil langsung pada halaman kamera.

Setelah kamera ditutup atau hasil pengenalan diterima, halaman detail mata pelajaran memperbarui status siswa menjadi hadir dan mengirimkan data tersebut ke backend. Backend memvalidasi dan menyimpan data, kemudian status tersebut dapat ditampilkan kembali melalui pengambilan data presensi berdasarkan tanggal. Halaman rekap menggunakan data kelas wali, siswa, jadwal kelas, mata pelajaran, dan data presensi untuk membentuk ringkasan kehadiran harian. Pengguna juga dapat memilih tanggal rekap dan menghasilkan laporan.

**Gambar 4.x Tampilan hasil presensi siswa pada detail mata pelajaran**

**Gambar 4.x Tampilan rekap kehadiran siswa**

Kedua gambar tersebut disarankan ditempatkan setelah penjelasan hasil dan rekap. Berdasarkan Gambar 4.x, hasil pengenalan tidak berhenti pada halaman kamera, tetapi diteruskan hingga memperbarui status siswa dan membentuk rekap yang dapat dimuat kembali.

Secara keseluruhan, alur penggunaan aplikasi mobile adalah sebagai berikut. Guru melakukan login, membuka dashboard, memilih jadwal mengajar, membuka detail mata pelajaran, dan menjalankan kamera presensi. Sistem kemudian mendeteksi serta mengenali wajah, mengubah status siswa yang memenuhi syarat menjadi hadir, menyimpan data melalui API, dan menampilkan hasil pada halaman detail serta rekap. Penggunaan isolate, pembatasan frame, dan waktu stabilisasi kamera mendukung responsivitas aplikasi selama proses tersebut berlangsung.

## 4.5.4 Hasil Integrasi Database Presensi

Basis data yang digunakan adalah MariaDB dengan nama basis data `presensi_db`. Backend mengakses basis data melalui SQLAlchemy dan driver PyMySQL. Integrasi basis data dirancang agar data hasil pengenalan wajah dapat dikaitkan dengan data akademik yang relevan. Tabel utama yang berhubungan langsung dengan proses presensi adalah tabel `siswa`, `embeddings`, `jadwal`, dan `presensi`. Tabel pendukung mencakup `guru`, `kelas`, `mata_pelajaran`, `tahun_pelajaran`, `siswa_kelas`, `guru_mapel`, dan `wali_kelas`.

Tabel `siswa` menyimpan identitas utama siswa. Satu siswa dapat memiliki beberapa baris pada tabel `embeddings`, sehingga beberapa contoh embedding wajah dapat digunakan dalam proses pencocokan. Relasi dilakukan melalui `embeddings.siswa_id` yang mengarah ke `siswa.id`. Saat kamera presensi untuk kelas dibuka, backend hanya mengembalikan embedding siswa aktif dalam kelas tersebut. Hal ini menjaga kesesuaian antara ruang pencarian identitas dan konteks kelas yang sedang dipresensi.

Tabel `jadwal` menghubungkan kelas, mata pelajaran, guru, tahun pelajaran, hari, jam mulai, dan jam selesai. Tabel `presensi` menghubungkan hasil kehadiran dengan siswa, jadwal, dan guru. Sebelum data disimpan, backend memastikan bahwa siswa, jadwal, dan guru tersedia; siswa termasuk dalam kelas serta tahun pelajaran jadwal; dan guru yang menjalankan presensi sesuai dengan guru pada jadwal.

Pencegahan data ganda diterapkan melalui validasi backend dan unique constraint `uq_presensi_siswa_jadwal_tanggal`. Constraint tersebut memastikan kombinasi siswa, jadwal, dan tanggal hanya memiliki satu catatan presensi. Apabila aplikasi mencoba menyimpan kombinasi yang sama, backend menolak duplikasi. Data yang telah tersimpan tetap tersedia setelah aplikasi ditutup atau pengguna login ulang karena halaman detail dan rekap memuat kembali data dari basis data.

Relasi tabel utama yang mendukung integrasi presensi dapat dilihat pada Tabel 4.x.

**Tabel 4.x Relasi tabel utama pada sistem presensi**

| Tabel | Relasi Utama | Peran dalam Integrasi |
|---|---|---|
| `siswa` | Berelasi dengan `embeddings`, `siswa_kelas`, dan `presensi` | Menyimpan identitas siswa yang dikenali |
| `embeddings` | `siswa_id` mengarah ke `siswa.id` | Menyimpan satu atau lebih embedding untuk setiap siswa |
| `kelas` | Berelasi dengan siswa, jadwal, siswa_kelas, dan wali kelas | Menentukan kelompok siswa yang dipresensi |
| `siswa_kelas` | Menghubungkan siswa, kelas, dan tahun pelajaran | Menentukan keanggotaan aktif siswa pada kelas dalam tahun pelajaran |
| `guru` | Berelasi dengan jadwal, guru_mapel, wali_kelas, dan presensi | Menentukan guru pengajar dan pelaksana presensi |
| `mata_pelajaran` | Berelasi dengan jadwal dan guru_mapel | Menentukan mata pelajaran pada jadwal |
| `jadwal` | Menghubungkan kelas, guru, mata pelajaran, dan tahun pelajaran | Menjadi konteks pelaksanaan presensi |
| `presensi` | Menghubungkan siswa, jadwal, dan guru | Menyimpan hasil akhir proses presensi |

Berdasarkan Tabel 4.x, data presensi tidak berdiri sendiri. Setiap catatan presensi memiliki keterkaitan dengan identitas siswa dan konteks jadwal. Relasi `siswa_kelas` dan `tahun_pelajaran` juga memungkinkan keanggotaan kelas siswa berubah pada tahun pelajaran berikutnya tanpa membuat ulang identitas utama siswa.

Struktur tabel `presensi` berdasarkan model backend dapat dilihat pada Tabel 4.x.

**Tabel 4.x Struktur tabel presensi**

| Field | Tipe Data | Keterangan |
|---|---|---|
| `id` | Integer, primary key | Identitas unik catatan presensi |
| `siswa_id` | Integer, foreign key, tidak null | Mengarah ke siswa yang dipresensi |
| `jadwal_id` | Integer, foreign key, tidak null | Mengarah ke jadwal pelajaran |
| `guru_id` | Integer, foreign key, tidak null | Mengarah ke guru pelaksana presensi |
| `status` | String(20) | Menyimpan status `hadir`, `izin`, `sakit`, atau `alpha` |
| `tanggal` | String(10) | Menyimpan tanggal presensi |
| `jam_presensi` | String(10) | Menyimpan waktu pencatatan presensi |
| Unique constraint | Kombinasi `siswa_id`, `jadwal_id`, dan `tanggal` | Mencegah presensi ganda pada jadwal dan tanggal yang sama |

Berdasarkan Tabel 4.x, struktur tabel presensi memuat field minimum yang dibutuhkan untuk menghubungkan hasil pengenalan dengan kegiatan pembelajaran. Status kehadiran otomatis dari kamera disimpan sebagai `hadir`, sedangkan status lain tetap didukung oleh model data.

Contoh catatan yang ditemukan pada basis data proyek saat pemeriksaan dapat dilihat pada Tabel 4.x. Data ini digunakan sebagai bukti bentuk penyimpanan, bukan sebagai hasil evaluasi akurasi sistem.

**Tabel 4.x Contoh data presensi yang tersimpan**

| ID | Siswa ID | Jadwal ID | Guru ID | Status | Tanggal | Jam Presensi |
|---:|---:|---:|---:|---|---|---|
| 12 | 14 | 20 | 8 | hadir | 2026-05-22 | 22:42 |
| 13 | 12 | 20 | 8 | hadir | 2026-05-22 | 22:42 |
| 14 | 13 | 20 | 8 | hadir | 2026-05-22 | 22:44 |

Berdasarkan Tabel 4.x, beberapa siswa dapat dicatat pada jadwal dan tanggal yang sama, tetapi masing-masing siswa memiliki baris presensi tersendiri. Data tersebut selanjutnya dapat diambil kembali berdasarkan tanggal atau jadwal untuk ditampilkan pada detail mata pelajaran dan rekap kehadiran.

Sebagai bukti visual integrasi basis data, disarankan menampilkan diagram relasi tabel dan tangkapan layar data hasil presensi setelah proses pengenalan.

**Gambar 4.x Diagram relasi tabel yang mendukung proses presensi**

**Gambar 4.x Data hasil presensi yang tersimpan pada MariaDB**

Berdasarkan Gambar 4.x, relasi tabel menunjukkan keterhubungan data siswa, embedding, jadwal, guru, dan presensi. Tampilan data MariaDB menunjukkan bahwa hasil pengenalan yang diperoleh dari aplikasi telah diteruskan dan disimpan sebagai catatan presensi.

Hasil keseluruhan integrasi menunjukkan bahwa aplikasi mobile, REST API, backend FastAPI, deteksi wajah YOLO, pengenalan MobileFaceNet, cosine similarity, dan MariaDB telah berhasil dihubungkan dalam satu sistem presensi. Integrasi tersebut memungkinkan proses dimulai dari pemilihan jadwal oleh guru, dilanjutkan dengan deteksi dan pengenalan satu atau beberapa wajah, kemudian diakhiri dengan penyimpanan serta penyajian kembali data kehadiran. Hasil integrasi ini menjadi dasar untuk pelaksanaan pengujian sistem presensi pada bagian 4.6.

## Saran Posisi Gambar

| Gambar yang Disarankan | Posisi Peletakan |
|---|---|
| Gambar 4.x Diagram arsitektur integrasi sistem presensi | Setelah Tabel komponen integrasi pada Subbab 4.5.1 |
| Gambar 4.x Tampilan halaman login aplikasi | Setelah paragraf autentikasi pada Subbab 4.5.3 |
| Gambar 4.x Tampilan dashboard guru dan jadwal mengajar | Setelah paragraf dashboard pada Subbab 4.5.3 |
| Gambar 4.x Tampilan detail mata pelajaran dan daftar siswa | Setelah penjelasan pemilihan jadwal pada Subbab 4.5.3 |
| Gambar 4.x Tampilan kamera presensi multi-wajah | Setelah penjelasan deteksi dan pengenalan realtime pada Subbab 4.5.3 |
| Gambar 4.x Tampilan hasil presensi siswa pada detail mata pelajaran | Setelah penjelasan perubahan status siswa pada Subbab 4.5.3 |
| Gambar 4.x Tampilan rekap kehadiran siswa | Setelah penjelasan rekap pada Subbab 4.5.3 |
| Gambar 4.x Diagram relasi tabel yang mendukung proses presensi | Setelah penjelasan relasi tabel pada Subbab 4.5.4 |
| Gambar 4.x Data hasil presensi yang tersimpan pada MariaDB | Setelah tabel contoh data presensi pada Subbab 4.5.4 |

## Data yang Masih Perlu Dilengkapi

1. **[PERLU DIISI: ukuran pasti tensor input dan output model YOLO dari hasil pemeriksaan model yang digunakan pada backend]**. Kode backend membaca ukuran tensor secara dinamis sehingga ukurannya tidak dapat dipastikan hanya dari konstanta aplikasi.
2. **[PERLU DIISI: metadata atau bukti hasil ekspor yang memastikan model `yolofacedetect.tflite` merupakan YOLO11n]**. Nama varian YOLO11n tidak tertulis secara eksplisit pada file kode.
3. **[PERLU DIISI: spesifikasi perangkat server, sistem operasi server, prosesor, RAM, serta lokasi deployment]** apabila informasi tersebut perlu dibahas dalam arsitektur implementasi.
4. **[PERLU DIISI: konfigurasi proses Cloudflared pada server]**. Repositori menunjukkan domain dan mekanisme pemilihan sumber API, tetapi tidak menunjukkan konfigurasi tunnel lengkap.
5. **[PERLU DIISI: nomor final tabel dan gambar]** sesuai urutan keseluruhan BAB IV.
6. **[PERLU DIISI: screenshot implementasi nyata]** untuk halaman login, dashboard guru, detail mata pelajaran, kamera presensi, hasil presensi, rekap, diagram relasi, dan data MariaDB.
7. **[PERLU DIISI: diagram arsitektur final]** yang menggambarkan bahwa YOLO berjalan di backend, sedangkan crop wajah, MobileFaceNet, dan cosine similarity berjalan di isolate aplikasi mobile.
