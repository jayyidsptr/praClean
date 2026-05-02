# Changelog PRA CLEAN Utility

Semua perubahan penting proyek ini didokumentasikan di sini.

Format mengikuti semangat Keep a Changelog dan proyek menggunakan Semantic Versioning.

## [1.1.0] - 2026-05-02

### Ditambahkan

- Mode `--dry-run` untuk simulasi tanpa mengubah sistem.
- Opsi `--no-ai` untuk menonaktifkan Gemini AI.
- Opsi `--help` dengan ringkasan penggunaan.
- Prompt API key Gemini saat fitur AI dipakai dan key belum tersedia.
- Validasi input paket, ukuran journald, durasi vacuum, dan jumlah baris log.
- Backup otomatis untuk `/etc/systemd/journald.conf` sebelum perubahan nyata.
- Pembersihan `/tmp` berbasis umur file sebagai default aman.
- Pembersihan cache pengguna berbasis umur file sebagai default aman.
- Konfirmasi terpisah untuk setiap operasi Docker prune.

### Diubah

- Skrip utama direfaktor menjadi fungsi `main` dengan parsing argumen.
- Gemini API key dikirim lewat header, bukan query string URL.
- Docker prune tidak lagi menjalankan operasi agresif tanpa konfirmasi khusus.
- Review log tidak lagi memakai `select`; menu angka eksplisit lebih jelas.
- README disinkronkan dengan perilaku aktual skrip.

### Keamanan

- Hapus semua isi `/tmp` sekarang butuh konfirmasi ganda.
- Penghapusan paket memakai array dan validasi nama paket.
- Temporary config/payload AI dibuat dengan permission `600` lalu dihapus.

## [1.0.0] - 2025-01-01

### Ditambahkan

- Menu interaktif PRA CLEAN.
- Pembersihan APT, `/var/log`, journald, `/tmp`, dan cache pengguna.
- Pembersihan cache NPM, Pip3, Go, Maven, dan Gradle.
- Pembersihan Docker dasar.
- Analisis disk dan tinjau log sistem.
- Integrasi awal Gemini AI.
