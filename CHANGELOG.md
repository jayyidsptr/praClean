Changelog PRA CLEAN Utility
Semua perubahan penting pada proyek ini akan didokumentasikan dalam file ini.

Formatnya didasarkan pada Keep a Changelog,
dan proyek ini menganut Semantic Versioning.

[Belum Dirilis]
Ditambahkan
Fitur atau peningkatan baru yang belum dirilis.

Diubah
Perubahan pada fungsionalitas yang sudah ada.

Tidak Digunakan Lagi (Deprecated)
Fitur yang akan dihapus di rilis mendatang.

Dihapus
Fitur yang telah dihapus.

Diperbaiki
Perbaikan bug.

Keamanan
Perbaikan terkait kerentanan keamanan.

[1.0.0] - YYYY-MM-DD
Ini adalah rilis awal dari PRA CLEAN Utility.

Ditambahkan
Seni ASCII "PRA CLEAN" dan kredit developer.

Menu utama interaktif dengan opsi pembersihan sistem dasar.

Pembersihan Sistem Umum:

Pembersihan Cache Apt-get (autoclean, clean, autoremove).

Opsi Hapus Paket Tertentu.

Pembersihan Log Lama (/var/log).

Konfigurasi & Pembersihan Journald (Systemd Logs) yang interaktif.

Penghapusan File Sementara (/tmp).

Pembersihan Cache Pengguna (~/.cache) dengan deteksi pengguna sudo.

Pembersihan Cache Aplikasi (Sub-menu):

Pembersihan Cache NPM.

Pembersihan Cache Pip3.

Pembersihan Cache Go.

Pembersihan Cache Maven.

Pembersihan Cache Gradle.
(Semua pembersihan cache aplikasi mencoba berjalan sebagai pengguna $SUDO_USER).

Pembersihan Docker:

Pembersihan image, volume, system prune, dan builder cache Docker yang komprehensif.

Utilitas Sistem (Sub-menu):

Analisis Penggunaan Disk (keseluruhan, direktori teratas, path spesifik).

Tinjau Log Sistem Penting (syslog, auth.log, dll., atau kustom).

Opsi "JALANKAN SEMUA Tugas Pembersihan Utama".

Pemeriksaan hak akses sudo di awal skrip.

Pesan berwarna untuk output yang lebih baik.

Fungsi press_enter_to_continue untuk pengalaman pengguna yang lebih baik.

Contoh Penggunaan Versi Sebelumnya:

[0.1.0] - YYYY-MM-DD (Contoh Versi Fiktif Sebelumnya)
Ditambahkan
Fungsi pembersihan apt-get dasar.

Menu awal yang sangat sederhana.