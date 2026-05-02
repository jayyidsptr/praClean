# Panduan Kontribusi untuk PRA CLEAN Utility

Terima kasih telah mempertimbangkan untuk berkontribusi pada PRA CLEAN Utility! Kami menyambut baik setiap kontribusi yang dapat membuat alat ini lebih baik.

Berikut adalah beberapa panduan tentang bagaimana Anda dapat berkontribusi:

## Cara Berkontribusi

Ada banyak cara untuk berkontribusi pada proyek ini, termasuk:

* **Melaporkan Bug:** Jika Anda menemukan bug atau perilaku yang tidak diharapkan, silakan buat *issue* baru di repositori GitHub. Sertakan langkah-langkah untuk mereproduksi bug, versi sistem operasi Anda, dan output atau pesan kesalahan yang relevan.
* **Menyarankan Fitur Baru:** Jika Anda memiliki ide untuk fitur baru atau peningkatan, silakan buat *issue* baru untuk mendiskusikannya. Jelaskan fitur tersebut dan mengapa menurut Anda itu akan bermanfaat.
* **Mengajukan Pull Request (PR):** Jika Anda ingin mengimplementasikan perbaikan bug atau fitur baru, Anda dapat melakukannya melalui *pull request*.
* **Memperbaiki Dokumentasi:** Jika Anda menemukan kesalahan ketik, informasi yang kurang jelas, atau bagian yang dapat diperbaiki dalam dokumentasi (seperti `README.md` ini atau komentar dalam kode), jangan ragu untuk memperbaikinya.

## Panduan untuk Pull Request

1.  **Fork Repositori:** Buat *fork* dari repositori utama ke akun GitHub Anda.
2.  **Buat Branch Baru:** Buat *branch* baru dari `main` (atau *branch* pengembangan utama jika ada) untuk pekerjaan Anda. Beri nama *branch* yang deskriptif, misalnya `fix/bug-apt-cache` atau `feature/new-log-analyzer`.
    ```bash
    git checkout -b nama-branch-anda
    ```
3.  **Lakukan Perubahan:** Lakukan perubahan kode atau dokumentasi yang diperlukan.
    * **Gaya Kode:** Usahakan untuk mengikuti gaya kode yang sudah ada dalam skrip. Komentari kode Anda jika menambahkan fungsionalitas yang kompleks.
    * **Pesan Commit:** Tulis pesan *commit* yang jelas dan ringkas yang menjelaskan perubahan yang Anda buat.
4.  **Uji Perubahan Anda:** Pastikan perubahan Anda berfungsi seperti yang diharapkan dan tidak menimbulkan masalah baru. Uji skrip pada sistem Linux yang relevan.
5.  **Push ke Branch Anda:** *Push* perubahan Anda ke *branch* di *fork* repositori Anda.
    ```bash
    git push origin nama-branch-anda
    ```
6.  **Buat Pull Request:** Buka *pull request* dari *branch* Anda di *fork* ke *branch* `main` di repositori utama.
    * Berikan judul dan deskripsi yang jelas untuk *pull request* Anda.
    * Jika *pull request* Anda terkait dengan *issue* yang sudah ada, sebutkan nomor *issue* tersebut (misalnya, "Closes #123").

## Proses Review

* Setelah Anda mengajukan *pull request*, pengelola proyek akan meninjaunya.
* Mungkin ada diskusi atau permintaan untuk perubahan lebih lanjut.
* Setelah disetujui, *pull request* Anda akan digabungkan ke dalam proyek.

## Kode Etik (Contoh Sederhana)

Kami bertujuan untuk menjaga lingkungan yang ramah dan inklusif. Semua kontributor diharapkan untuk mengikuti standar perilaku profesional dan menghormati satu sama lain.

---

Terima kasih atas kontribusi Anda!
