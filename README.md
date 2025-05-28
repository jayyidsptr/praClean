# PRA CLEAN Utility (AI-Enhanced)

## Deskripsi Singkat Proyek

PRA CLEAN Utility adalah sebuah skrip Bash interaktif yang canggih, dirancang untuk membantu pengguna membersihkan, mengelola, dan memahami server Linux mereka (khususnya distribusi berbasis Debian seperti Ubuntu). Skrip ini menyediakan berbagai opsi pembersihan sistem, cache aplikasi, log, dan utilitas Docker, serta beberapa alat bantu sistem tambahan. Yang membuatnya unik adalah **integrasi dengan AI Gemini** untuk memberikan penjelasan perintah, analisis log, dan saran optimasi, semuanya dalam antarmuka menu yang mudah digunakan, berwarna, dan dengan rendering Markdown yang lebih baik jika `glow` terinstal.

**Dikembangkan oleh:** jayyidsptr
**GitHub:** [https://github.com/jayyidsptr](https://github.com/jayyidsptr)

## Fitur Utama

* **Antarmuka Interaktif Berwarna Modern:** Menu yang mudah dinavigasi dengan output berwarna, animasi loading, dan bingkai menu yang lebih rapi.
* **Integrasi AI Gemini (Eksperimental):**
    * **Penjelasan Perintah Berisiko:** Dapatkan penjelasan detail dari AI Gemini tentang perintah-perintah sistem yang berpotensi berbahaya sebelum menjalankannya.
    * **Analisis Log dengan AI:** Minta AI Gemini untuk menganalisis potongan log sistem dan memberikan ringkasan potensi masalah atau error.
    * **Saran Optimasi Disk dengan AI:** Dapatkan saran dari AI Gemini tentang cara mengoptimalkan ruang disk berdasarkan analisis direktori tertentu.
    * **Penjelasan Dampak Penghapusan Paket:** Pahami lebih baik apa fungsi sebuah paket dan potensi dampaknya sebelum menghapusnya.
* **Rendering Markdown yang Ditingkatkan:** Jika `glow` terinstal, penjelasan AI akan ditampilkan dalam format Markdown yang rapi di terminal.
* **Pembersihan Sistem Umum:**
    * Membersihkan cache `apt-get` (`autoclean`, `clean`).
    * Menghapus paket yang tidak lagi diperlukan (`autoremove`).
    * Opsi untuk menghapus paket tertentu yang ditentukan pengguna (dengan opsi penjelasan AI).
    * Membersihkan log lama di direktori `/var/log` (dengan opsi penjelasan AI).
    * Mengkonfigurasi dan membersihkan log `journald` (Systemd Logs) yang interaktif (dengan opsi penjelasan AI).
    * Menghapus file sementara di `/tmp` (dengan opsi penjelasan AI).
    * Membersihkan cache pengguna di `~/.cache` (dengan opsi penjelasan AI dan deteksi pengguna `sudo`).
* **Pembersihan Cache Aplikasi (Sub-menu):**
    * Membersihkan cache NPM, Pip3, Go, Maven, dan Gradle (berusaha berjalan sebagai pengguna `$SUDO_USER`).
* **Pembersihan Docker (dengan opsi penjelasan AI):**
    * Memangkas image Docker yang menggantung.
    * Opsi untuk memangkas semua image Docker yang tidak terpakai.
    * Memangkas volume Docker yang tidak terpakai.
    * Melakukan `docker system prune` (termasuk opsi `-a`).
    * Memangkas cache builder Docker.
* **Utilitas Sistem:**
    * **Analisis Penggunaan Disk:** Menampilkan penggunaan disk keseluruhan dan direktori teratas, serta opsi untuk menganalisis path tertentu (dengan opsi saran optimasi AI).
    * **Tinjau Log Sistem Penting:** Memungkinkan pengguna untuk melihat beberapa baris terakhir dari log sistem umum atau log kustom (dengan opsi analisis AI).
* **Pemeriksaan Hak Akses `sudo` & Dependensi:** Skrip secara otomatis memeriksa hak akses root dan dependensi yang diperlukan (termasuk untuk fitur AI).
* **Konfirmasi Pengguna:** Meminta konfirmasi untuk operasi yang berpotensi destruktif.
* **Opsi "Jalankan Semua":** Untuk menjalankan sebagian besar tugas pembersihan secara berurutan.

## Persyaratan

* **Sistem Operasi:** Distribusi Linux berbasis Debian (misalnya, Ubuntu, Linux Mint).
* **Bash Shell.**
* **Perintah Sistem Standar:** `apt-get`, `journalctl`, `rm`, `find`, `du`, `df`, `docker`, `npm`, `pip3`, `go`, `mvn`, `gradle` (jika terinstal).
* **Hak Akses `sudo`:** Diperlukan untuk sebagian besar operasi.
* **Untuk Fitur AI Gemini:**
    * **`curl`:** Untuk membuat permintaan API.
    * **`jq`:** Untuk mem-parsing respons JSON dari API.
    * **Koneksi Internet Aktif.**
    * **API Key Gemini:** Dari Google AI Studio atau Vertex AI.
    * **`glow` (Opsional, Sangat Direkomendasikan):** Untuk rendering output Markdown dari AI yang jauh lebih baik di terminal. (Kunjungi: [https://github.com/charmbracelet/glow](https://github.com/charmbracelet/glow))

## Cara Penggunaan

1.  **Unduh/Clone Skrip:**
    ```bash
    git clone [https://github.com/jayyidsptr/praClean.git](https://github.com/jayyidsptr/praClean.git)
    cd praClean
    ```

2.  **Instal Dependensi (jika belum ada):**
    ```bash
    sudo apt update
    sudo apt install curl jq -y
    # Opsional tapi sangat direkomendasikan untuk tampilan AI yang lebih baik:
    # Ikuti petunjuk instalasi 'glow' dari halaman GitHub mereka.
    # Contoh (mungkin berbeda tergantung distribusi/versi):
    # sudo mkdir -p /etc/apt/keyrings
    # curl -fsSL [https://repo.charm.sh/apt/gpg.key](https://repo.charm.sh/apt/gpg.key) | sudo gpg --dearmor -o /etc/apt/keyrings/charm.gpg
    # echo "deb [signed-by=/etc/apt/keyrings/charm.gpg] [https://repo.charm.sh/apt/](https://repo.charm.sh/apt/) * *" | sudo tee /etc/apt/sources.list.d/charm.list
    # sudo apt update && sudo apt install glow
    ```

3.  **Buat Skrip Dapat Dieksekusi:**
    ```bash
    chmod +x praClean.sh 
    ```

4.  **Atur API Key Gemini (Opsional, tapi disarankan untuk penggunaan berulang):**
    Anda dapat mengatur variabel environment `PRA_CLEAN_GEMINI_API_KEY` dengan API Key Anda.
    ```bash
    export PRA_CLEAN_GEMINI_API_KEY="API_KEY_ANDA_DISINI"
    ```
    Jika tidak diatur, skrip akan meminta API Key saat fitur AI pertama kali digunakan.

5.  **Jalankan Skrip:**
    Jalankan skrip dengan `sudo`. Jika Anda mengatur environment variable di atas, gunakan opsi `-E` dengan `sudo` agar variabel tersebut diteruskan.
    ```bash
    sudo -E ./praClean.sh 
    # atau jika tidak mengatur env var:
    # sudo ./praClean.sh
    ```

6.  **Navigasi Menu:**
    Ikuti menu interaktif. Opsi yang terintegrasi dengan AI akan ditandai.

## Peringatan Penting

* **JALANKAN DENGAN HATI-HATI:** Skrip ini melakukan operasi yang dapat menghapus file dan mengubah konfigurasi sistem.
* **BACKUP DATA ANDA:** Sebelum menjalankan skrip ini, terutama pada sistem produksi, **buatlah backup data Anda**.
* **FITUR AI EKSPERIMENTAL:** Penjelasan dan saran dari AI Gemini bersifat sebagai panduan dan mungkin tidak selalu 100% akurat atau lengkap. Selalu gunakan penilaian Anda sendiri dan verifikasi informasi jika ragu. Pengembang tidak bertanggung jawab atas keputusan yang diambil berdasarkan output AI.
* **PAHAMI APA YANG ANDA LAKUKAN:** Pastikan Anda memahami tindakan apa yang akan dilakukan oleh setiap opsi sebelum melanjutkannya.

## Lisensi

Proyek ini dilisensikan di bawah [Lisensi MIT](LICENSE).

## Kontribusi

Kontribusi dalam bentuk laporan bug, permintaan fitur, atau *pull request* sangat diterima. Silakan buka *issue* di repositori GitHub untuk diskusi lebih lanjut. Lihat [CONTRIBUTING.md](CONTRIBUTING.md).

---

Semoga PRA CLEAN Utility (AI-Enhanced) bermanfaat!
