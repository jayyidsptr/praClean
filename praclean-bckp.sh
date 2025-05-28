#!/bin/bash

# --- Definisi Warna ---
DEFAULT_COLOR='\e[0m'
BLACK='\e[0;30m'
RED='\e[0;31m'
GREEN='\e[0;32m'
YELLOW='\e[0;33m'
BLUE='\e[0;34m'
MAGENTA='\e[0;35m'
CYAN='\e[0;36m'
WHITE='\e[0;37m'

BOLD_BLACK='\e[1;30m'
BOLD_RED='\e[1;31m'
BOLD_GREEN='\e[1;32m'
BOLD_YELLOW='\e[1;33m'
BOLD_BLUE='\e[1;34m'
BOLD_MAGENTA='\e[1;35m'
BOLD_CYAN='\e[1;36m'
BOLD_WHITE='\e[1;37m'

# Pesan Status
INFO_PREFIX="${BOLD_BLUE}[INFO]${DEFAULT_COLOR}"
WARNING_PREFIX="${BOLD_YELLOW}[PERINGATAN]${DEFAULT_COLOR}"
ERROR_PREFIX="${BOLD_RED}[ERROR]${DEFAULT_COLOR}"
SUCCESS_PREFIX="${BOLD_GREEN}[BERHASIL]${DEFAULT_COLOR}"
SKIPPED_PREFIX="${YELLOW}[DILEWATI]${DEFAULT_COLOR}"
QUESTION_PREFIX="${BOLD_CYAN}[PERTANYAAN]${DEFAULT_COLOR}"

# --- Fungsi Animasi Loading ---
show_loading_animation() {
    local duration=2 # Durasi animasi dalam detik
    local spinstr='|/-\\'
    local delay=0.1
    local i=0
    local end_time=$((SECONDS + duration))

    echo
    tput civis # Sembunyikan kursor
    while [ $SECONDS -lt $end_time ]; do
        local temp=${spinstr#?}
        printf "  ${BOLD_CYAN}Memuat PRA CLEAN Utility %c ${DEFAULT_COLOR}" "$spinstr"
        local spinstr=$temp${spinstr%"$temp"}
        sleep $delay
        printf "\r" # Kembali ke awal baris
    done
    printf "                                        \r" # Hapus baris animasi
    tput cnorm # Tampilkan kursor kembali
    echo
}


# --- Pemeriksaan Hak Akses Root ---
check_sudo() {
    if [[ "$EUID" -ne 0 ]]; then
        echo -e "${WARNING_PREFIX} Skrip ini memerlukan hak akses root untuk beberapa operasi."
        echo -e "${INFO_PREFIX} Silakan jalankan ulang dengan sudo: sudo $0"
        exit 1
    fi
}

# Panggil pemeriksaan sudo di awal
check_sudo
# Panggil animasi loading
show_loading_animation

# Fungsi untuk menampilkan seni ASCII
show_ascii_art() {
# Menggunakan warna langsung di sini untuk seni ASCII yang lebih terkontrol
echo -e "${BOLD_GREEN}"
cat << "EOF"
        PPPP   RRRR    AAA       CCCC  L      EEEEEE  AAA   NN   NN
        P   P  R   R  A   A     C      L      E      A   A  N N  N
        PPPP   RRRR   AAAAA     C      L      EEEE   AAAAA  N  N N
        P      R  R  A     A     C      L      E      A   A  N   NN
        P      R   R A       A   CCCC  LLLLL  EEEEEE A     A N    N
EOF
echo -e "${DEFAULT_COLOR}" # Reset warna setelah ASCII
echo -e "${BOLD_MAGENTA}=======================================================================${DEFAULT_COLOR}"
echo -e "${BOLD_MAGENTA}                        PRA CLEAN UTILITY                             ${DEFAULT_COLOR}"
echo -e "${BOLD_MAGENTA}=======================================================================${DEFAULT_COLOR}"
echo -e "${CYAN}                        Developed by: jayyidsptr                       ${DEFAULT_COLOR}"
echo -e "${CYAN}                 https://github.com/jayyidsptr                      ${DEFAULT_COLOR}"
echo
}

# --- Fungsi Utilitas ---
press_enter_to_continue() {
    echo # Tambahkan baris kosong sebelum prompt
    read -n 1 -s -r -p "$(echo -e "  ${YELLOW}Tekan Enter untuk kembali ke menu...${DEFAULT_COLOR}")"
}

# --- Fungsi Pembersihan ---

# 1. Pembersihan Apt-get
clean_apt() {
    echo
    echo -e "  ${INFO_PREFIX} Membersihkan cache apt-get..."
    apt-get autoclean -y
    apt-get clean -y
    echo -e "  ${INFO_PREFIX} Menghapus paket yang tidak terpakai (autoremove)..."
    apt-get autoremove -y
    echo -e "  ${SUCCESS_PREFIX} Pembersihan apt-get selesai."
    press_enter_to_continue
}

# 2. Hapus Paket Tertentu
remove_specific_packages() {
    echo
    echo -e "  ${INFO_PREFIX} Menghapus perangkat lunak tertentu yang tidak diinginkan..."
    read -p "$(echo -e "  ${QUESTION_PREFIX} Masukkan nama paket yang akan dihapus (pisahkan dengan spasi, biarkan kosong untuk melewati): ")" packages_to_remove
    if [ -n "$packages_to_remove" ]; then
        # shellcheck disable=SC2086
        apt-get remove $packages_to_remove -y
        echo -e "  ${SUCCESS_PREFIX} Penghapusan paket tertentu selesai."
    else
        echo -e "  ${SKIPPED_PREFIX} Tidak ada paket yang ditentukan untuk dihapus."
    fi
    press_enter_to_continue
}

# 3. Bersihkan Log Lama (/var/log)
clean_var_log() {
    echo
    echo -e "  ${INFO_PREFIX} Membersihkan log lama di /var/log..."
    echo -e "  ${WARNING_PREFIX} Perintah berikutnya akan menghapus semua file di /var/log. Pastikan ini memang diinginkan."
    echo -e "  ${YELLOW}Anda mungkin ingin memeriksa file log besar terlebih dahulu menggunakan: cd /var/log && du -h . | sort -hr | head -n 10${DEFAULT_COLOR}"
    read -p "$(echo -e "  ${QUESTION_PREFIX} Lanjutkan menghapus semua file di /var/log? (${BOLD_GREEN}yes${DEFAULT_COLOR}/${BOLD_RED}NO${DEFAULT_COLOR}): ")" confirm_var_log
    if [[ "$confirm_var_log" == "yes" ]]; then
        cd /var/log || { echo -e "  ${ERROR_PREFIX} Gagal pindah direktori ke /var/log. Pembatalan pembersihan log."; press_enter_to_continue; return 1; }
        rm -rf ./* # Lebih spesifik
        echo -e "  ${SUCCESS_PREFIX} Log lama di /var/log telah dibersihkan."
    else
        echo -e "  ${SKIPPED_PREFIX} Pembersihan /var/log dilewati oleh pengguna."
    fi
    press_enter_to_continue
}

# 4. Konfigurasi dan Bersihkan Journald (Systemd Logs)
configure_clean_journald() {
    echo
    echo -e "  ${INFO_PREFIX} Mengkonfigurasi dan membersihkan systemd journald..."

    local current_max_use
    local current_max_file_size
    current_max_use=$(grep -Po '^SystemMaxUse=\K[^ ]+' /etc/systemd/journald.conf 2>/dev/null || echo "Tidak diatur")
    current_max_file_size=$(grep -Po '^SystemMaxFileSize=\K[^ ]+' /etc/systemd/journald.conf 2>/dev/null || echo "Tidak diatur")

    echo -e "  ${CYAN}Konfigurasi saat ini:${DEFAULT_COLOR}"
    echo -e "    SystemMaxUse: ${BOLD_YELLOW}${current_max_use}${DEFAULT_COLOR}"
    echo -e "    SystemMaxFileSize: ${BOLD_YELLOW}${current_max_file_size}${DEFAULT_COLOR}"
    echo

    read -p "$(echo -e "  ${QUESTION_PREFIX} Apakah Anda ingin mengubah konfigurasi ukuran log journald? (${BOLD_GREEN}yes${DEFAULT_COLOR}/${BOLD_RED}NO${DEFAULT_COLOR}): ")" change_conf
    if [[ "$change_conf" == "yes" ]]; then
        read -p "$(echo -e "  ${QUESTION_PREFIX} Atur SystemMaxUse (cth: 1G, 500M, kosongkan untuk tidak mengubah): ")" new_max_use
        read -p "$(echo -e "  ${QUESTION_PREFIX} Atur SystemMaxFileSize (cth: 50M, 100M, kosongkan untuk tidak mengubah): ")" new_max_file_size

        if [ -f /etc/systemd/journald.conf ]; then
            if [ -n "$new_max_use" ]; then
                if grep -q "^SystemMaxUse=" /etc/systemd/journald.conf; then
                    sed -i "s/^SystemMaxUse=.*/SystemMaxUse=${new_max_use}/" /etc/systemd/journald.conf
                else
                    sed -i '/\[Journal\]/a SystemMaxUse='"${new_max_use}" /etc/systemd/journald.conf
                fi
                echo -e "  ${INFO_PREFIX} SystemMaxUse diatur ke ${new_max_use}."
            fi
            if [ -n "$new_max_file_size" ]; then
                if grep -q "^SystemMaxFileSize=" /etc/systemd/journald.conf; then
                    sed -i "s/^SystemMaxFileSize=.*/SystemMaxFileSize=${new_max_file_size}/" /etc/systemd/journald.conf
                else
                    sed -i '/\[Journal\]/a SystemMaxFileSize='"${new_max_file_size}" /etc/systemd/journald.conf
                fi
                echo -e "  ${INFO_PREFIX} SystemMaxFileSize diatur ke ${new_max_file_size}."
            fi
            if [ -n "$new_max_use" ] || [ -n "$new_max_file_size" ]; then
                 echo -e "  ${INFO_PREFIX} Merestart systemd-journald untuk menerapkan perubahan..."
                 systemctl restart systemd-journald
            else
                echo -e "  ${INFO_PREFIX} Tidak ada perubahan konfigurasi yang dibuat."
            fi
        else
            echo -e "  ${WARNING_PREFIX} /etc/systemd/journald.conf tidak ditemukan. Tidak dapat mengubah konfigurasi."
        fi
    fi
    echo

    echo -e "  ${INFO_PREFIX} Membersihkan log systemd journal..."
    read -p "$(echo -e "  ${QUESTION_PREFIX} Bersihkan log journald berdasarkan waktu? (cth: 2d, 1week, kosongkan untuk melewati): ")" vacuum_time
    if [ -n "$vacuum_time" ]; then
        journalctl --vacuum-time="$vacuum_time"
        echo -e "  ${INFO_PREFIX} Log journald yang lebih tua dari ${vacuum_time} telah dibersihkan."
    fi

    read -p "$(echo -e "  ${QUESTION_PREFIX} Bersihkan log journald berdasarkan ukuran? (cth: 100M, 500M, kosongkan untuk melewati): ")" vacuum_size
    if [ -n "$vacuum_size" ]; then
        journalctl --vacuum-size="$vacuum_size"
        echo -e "  ${INFO_PREFIX} Log journald dibatasi hingga ${vacuum_size}."
    fi

    echo -e "  ${SUCCESS_PREFIX} Pembersihan dan konfigurasi Journald selesai."
    press_enter_to_continue
}

# 5. Hapus File Sementara (/tmp)
clean_tmp_files() {
    echo
    echo -e "  ${INFO_PREFIX} Membersihkan file sementara di /tmp..."
    echo -e "  ${WARNING_PREFIX} Perintah berikutnya akan menghapus semua file di /tmp. Pastikan ini memang diinginkan."
    read -p "$(echo -e "  ${QUESTION_PREFIX} Lanjutkan menghapus semua file di /tmp? (${BOLD_GREEN}yes${DEFAULT_COLOR}/${BOLD_RED}NO${DEFAULT_COLOR}): ")" confirm_tmp
    if [[ "$confirm_tmp" == "yes" ]]; then
        cd /tmp || { echo -e "  ${ERROR_PREFIX} Gagal pindah direktori ke /tmp. Pembatalan pembersihan /tmp."; press_enter_to_continue; return 1; }
        rm -rf ./* # Lebih spesifik
        echo -e "  ${SUCCESS_PREFIX} File sementara di /tmp telah dibersihkan."
    else
        echo -e "  ${SKIPPED_PREFIX} Pembersihan /tmp dilewati oleh pengguna."
    fi
    press_enter_to_continue
}

# 6. Bersihkan Cache Pengguna (~/.cache)
clean_user_cache() {
    echo
    local user_home
    user_home=$(getent passwd "$SUDO_USER" | cut -d: -f6)
    local user_cache_dir="$user_home/.cache"

    if [ -z "$user_home" ] || [ ! -d "$user_cache_dir" ]; then
        echo -e "  ${WARNING_PREFIX} Tidak dapat menemukan direktori cache untuk pengguna $SUDO_USER ($user_cache_dir). Melewati."
        press_enter_to_continue
        return
    fi

    echo -e "  ${INFO_PREFIX} Membersihkan direktori cache pengguna (${BOLD_YELLOW}${user_cache_dir}${DEFAULT_COLOR})..."
    echo -e "  ${CYAN}10 item terbesar di ${user_cache_dir}:${DEFAULT_COLOR}"
    sudo -u "$SUDO_USER" du -sh "$user_cache_dir"/* 2>/dev/null | sort -hr | head -n 10
    echo -e "  ${WARNING_PREFIX} Perintah berikutnya akan menghapus semua file di ${user_cache_dir}. Pastikan ini memang diinginkan."
    read -p "$(echo -e "  ${QUESTION_PREFIX} Lanjutkan menghapus semua file di ${user_cache_dir}? (${BOLD_GREEN}yes${DEFAULT_COLOR}/${BOLD_RED}NO${DEFAULT_COLOR}): ")" confirm_user_cache
    if [[ "$confirm_user_cache" == "yes" ]]; then
        sudo -u "$SUDO_USER" find "$user_cache_dir" -mindepth 1 -delete
        echo -e "  ${SUCCESS_PREFIX} Cache pengguna (${user_cache_dir}) telah dibersihkan."
    else
        echo -e "  ${SKIPPED_PREFIX} Pembersihan ${user_cache_dir} dilewati oleh pengguna."
    fi
    press_enter_to_continue
}

# --- Sub Menu Pembersihan Cache Aplikasi ---
submenu_app_cache_cleanup() {
    while true; do
        clear
        show_ascii_art # Tampilkan header di setiap tampilan submenu
        echo -e "  ╭────────────────────────────────────────────────────╮"
        echo -e "  │ ${BOLD_WHITE}Pembersihan Cache Aplikasi${DEFAULT_COLOR}                         │"
        echo -e "  ├────────────────────────────────────────────────────┤"
        echo -e "  │ ${BOLD_YELLOW}1.${DEFAULT_COLOR} Bersihkan Cache NPM                              │"
        echo -e "  │ ${BOLD_YELLOW}2.${DEFAULT_COLOR} Bersihkan Cache Pip3                             │"
        echo -e "  │ ${BOLD_YELLOW}3.${DEFAULT_COLOR} Bersihkan Cache Go                               │"
        echo -e "  │ ${BOLD_YELLOW}4.${DEFAULT_COLOR} Bersihkan Cache Maven                            │"
        echo -e "  │ ${BOLD_YELLOW}5.${DEFAULT_COLOR} Bersihkan Cache Gradle                           │"
        echo -e "  │ ${BOLD_YELLOW}0.${DEFAULT_COLOR} ${BOLD_RED}Kembali ke Menu Utama${DEFAULT_COLOR}                       │"
        echo -e "  ╰────────────────────────────────────────────────────╯"
        read -p "$(echo -e "  ${BOLD_WHITE}Masukkan pilihan Anda [0-5]: ${DEFAULT_COLOR}")" app_cache_choice

        # Tambahkan clear sebelum memanggil fungsi untuk membersihkan tampilan menu
        case $app_cache_choice in
            1) clear; clean_npm_cache ;;
            2) clear; clean_pip3_cache ;;
            3) clear; clean_go_cache ;;
            4) clear; clean_maven_cache ;;
            5) clear; clean_gradle_cache ;;
            0) break ;;
            *) echo -e "  ${ERROR_PREFIX} Pilihan tidak valid." ; sleep 2 ;;
        esac
    done
}

# Fungsi pembersihan cache aplikasi (NPM, Pip3, Go, Maven, Gradle) tetap sama, hanya perlu dipanggil
# 7. Bersihkan Cache NPM
clean_npm_cache() {
    echo
    echo -e "  ${INFO_PREFIX} Membersihkan cache NPM..."
    if command -v npm &> /dev/null; then
        local user_home
        user_home=$(getent passwd "$SUDO_USER" | cut -d: -f6)
        if [ -n "$SUDO_USER" ] && [ "$SUDO_USER" != "root" ]; then
             sudo -u "$SUDO_USER" npm cache clean --force
             sudo -u "$SUDO_USER" npm cache verify
        else
            npm cache clean --force
            npm cache verify
        fi
        echo -e "  ${SUCCESS_PREFIX} Pembersihan cache NPM selesai."
    else
        echo -e "  ${SKIPPED_PREFIX} Perintah npm tidak ditemukan. Melewati pembersihan cache NPM."
    fi
    press_enter_to_continue
}

# 8. Bersihkan Cache Pip3
clean_pip3_cache() {
    echo
    echo -e "  ${INFO_PREFIX} Membersihkan cache Pip3..."
    if command -v pip3 &> /dev/null; then
        echo -e "  ${CYAN}Info cache Pip3:${DEFAULT_COLOR}"
        if [ -n "$SUDO_USER" ] && [ "$SUDO_USER" != "root" ]; then
            sudo -u "$SUDO_USER" pip3 cache info
            sudo -u "$SUDO_USER" pip3 cache purge
        else
            pip3 cache info
            pip3 cache purge
        fi
        echo -e "  ${SUCCESS_PREFIX} Pembersihan cache Pip3 selesai."
    else
        echo -e "  ${SKIPPED_PREFIX} Perintah pip3 tidak ditemukan. Melewati pembersihan cache Pip3."
    fi
    press_enter_to_continue
}

# 9. Bersihkan Cache Go
clean_go_cache() {
    echo
    echo -e "  ${INFO_PREFIX} Membersihkan cache Go..."
    if command -v go &> /dev/null; then
        local go_user="$SUDO_USER"
        [ -z "$go_user" ] || [ "$go_user" == "root" ] && go_user="root"

        local GOCACHE_DIR
        GOCACHE_DIR=$(sudo -u "$go_user" go env GOCACHE 2>/dev/null)

        if [ -n "$GOCACHE_DIR" ] && [ -d "$GOCACHE_DIR" ]; then
            echo -e "  ${CYAN}Ukuran direktori cache Go ($GOCACHE_DIR):${DEFAULT_COLOR}"
            sudo -u "$go_user" du -sh "$GOCACHE_DIR"
            sudo -u "$go_user" go clean -cache
            sudo -u "$go_user" go clean -modcache
            echo -e "  ${SUCCESS_PREFIX} Pembersihan cache Go selesai."
        else
            echo -e "  ${SKIPPED_PREFIX} Direktori cache Go tidak ditemukan atau tidak dapat diakses untuk pengguna $go_user. Melewati."
        fi
    else
        echo -e "  ${SKIPPED_PREFIX} Perintah go tidak ditemukan. Melewati pembersihan cache Go."
    fi
    press_enter_to_continue
}

# 10. Bersihkan Cache Maven
clean_maven_cache() {
    echo
    echo -e "  ${INFO_PREFIX} Membersihkan cache Maven..."
    local user_home
    user_home=$(getent passwd "$SUDO_USER" | cut -d: -f6)
    local maven_repo_dir="$user_home/.m2/repository"

    if [ -z "$user_home" ]; then
         user_home=$(getent passwd "root" | cut -d: -f6)
         maven_repo_dir="$user_home/.m2/repository"
    fi

    if [ -d "$maven_repo_dir" ]; then
        echo -e "  ${INFO_PREFIX} Membersihkan cache Maven (${BOLD_YELLOW}${maven_repo_dir}${DEFAULT_COLOR})..."
        echo -e "  ${WARNING_PREFIX} Perintah berikutnya akan menghapus repositori Maven."
        read -p "$(echo -e "  ${QUESTION_PREFIX} Lanjutkan menghapus repositori Maven? (${BOLD_GREEN}yes${DEFAULT_COLOR}/${BOLD_RED}NO${DEFAULT_COLOR}): ")" confirm_maven_cache
        if [[ "$confirm_maven_cache" == "yes" ]]; then
            sudo -u "$SUDO_USER" rm -rf "$maven_repo_dir"
            echo -e "  ${SUCCESS_PREFIX} Cache Maven telah dibersihkan."
        else
            echo -e "  ${SKIPPED_PREFIX} Pembersihan cache Maven dilewati oleh pengguna."
        fi
    else
        echo -e "  ${SKIPPED_PREFIX} Direktori ${maven_repo_dir} tidak ditemukan. Melewati pembersihan cache Maven."
    fi
    press_enter_to_continue
}

# 11. Bersihkan Cache Gradle
clean_gradle_cache() {
    echo
    echo -e "  ${INFO_PREFIX} Membersihkan cache Gradle..."
    local user_home
    user_home=$(getent passwd "$SUDO_USER" | cut -d: -f6)
    local gradle_cache_dir="$user_home/.gradle/caches"

    if [ -z "$user_home" ]; then
         user_home=$(getent passwd "root" | cut -d: -f6)
         gradle_cache_dir="$user_home/.gradle/caches"
    fi

    if [ -d "$gradle_cache_dir" ]; then
        echo -e "  ${INFO_PREFIX} Membersihkan cache Gradle (${BOLD_YELLOW}${gradle_cache_dir}${DEFAULT_COLOR})..."
        if command -v gradle &> /dev/null; then
            echo -e "  ${INFO_PREFIX} Mencoba menghentikan daemon Gradle global (jika berjalan)..."
            sudo -u "$SUDO_USER" gradle --stop > /dev/null 2>&1
        fi

        echo -e "  ${WARNING_PREFIX} Perintah berikutnya akan menghapus cache Gradle."
        read -p "$(echo -e "  ${QUESTION_PREFIX} Lanjutkan menghapus cache Gradle? (${BOLD_GREEN}yes${DEFAULT_COLOR}/${BOLD_RED}NO${DEFAULT_COLOR}): ")" confirm_gradle_cache
        if [[ "$confirm_gradle_cache" == "yes" ]]; then
            sudo -u "$SUDO_USER" rm -rf "$gradle_cache_dir"
            echo -e "  ${SUCCESS_PREFIX} Cache Gradle telah dibersihkan."
        else
            echo -e "  ${SKIPPED_PREFIX} Pembersihan cache Gradle dilewati oleh pengguna."
        fi
    else
        echo -e "  ${SKIPPED_PREFIX} Direktori ${gradle_cache_dir} tidak ditemukan. Melewati pembersihan cache Gradle."
    fi
    press_enter_to_continue
}


# 12. Pembersihan Docker
clean_docker() {
    echo
    echo -e "  ${INFO_PREFIX} Memulai Pembersihan Docker..."
    if command -v docker &> /dev/null; then
        echo -e "  ${CYAN}Ukuran direktori Docker (/var/lib/docker):${DEFAULT_COLOR}"
        du -sh /var/lib/docker
        echo

        echo -e "  ${CYAN}Menampilkan Image Docker (aktif dan semua):${DEFAULT_COLOR}"
        docker images -a
        echo

        echo -e "  ${INFO_PREFIX} Memangkas image Docker yang menggantung (dangling)..."
        docker image prune -f
        echo

        read -p "$(echo -e "  ${QUESTION_PREFIX} Lanjutkan memangkas SEMUA image Docker yang tidak terpakai? (${BOLD_GREEN}yes${DEFAULT_COLOR}/${BOLD_RED}NO${DEFAULT_COLOR}): ")" confirm_docker_prune_a
        if [[ "$confirm_docker_prune_a" == "yes" ]]; then
            echo -e "  ${INFO_PREFIX} Memangkas semua image Docker yang tidak terpakai..."
            docker image prune -a -f
            echo -e "  ${SUCCESS_PREFIX} Semua image yang tidak terpakai telah dipangkas."
        else
            echo -e "  ${SKIPPED_PREFIX} Pemangkasan semua image yang tidak terpakai dilewati oleh pengguna."
        fi
        echo

        echo -e "  ${INFO_PREFIX} Memangkas volume Docker yang tidak terpakai..."
        docker volume prune -f
        echo

        echo -e "  ${INFO_PREFIX} Melakukan Docker system prune..."
        docker system prune -f
        echo

        read -p "$(echo -e "  ${QUESTION_PREFIX} Lanjutkan dengan Docker system prune -a? (${BOLD_GREEN}yes${DEFAULT_COLOR}/${BOLD_RED}NO${DEFAULT_COLOR}): ")" confirm_docker_system_prune_a
        if [[ "$confirm_docker_system_prune_a" == "yes" ]]; then
            echo -e "  ${INFO_PREFIX} Melakukan Docker system prune -a..."
            docker system prune -a -f
            echo -e "  ${SUCCESS_PREFIX} Docker system prune -a selesai."
        else
            echo -e "  ${SKIPPED_PREFIX} Docker system prune -a dilewati oleh pengguna."
        fi
        echo

        echo -e "  ${INFO_PREFIX} Memangkas cache builder Docker..."
        docker builder prune -f
        echo

        read -p "$(echo -e "  ${QUESTION_PREFIX} Lanjutkan memangkas SEMUA cache builder Docker? (${BOLD_GREEN}yes${DEFAULT_COLOR}/${BOLD_RED}NO${DEFAULT_COLOR}): ")" confirm_docker_builder_prune_a
        if [[ "$confirm_docker_builder_prune_a" == "yes" ]]; then
            echo -e "  ${INFO_PREFIX} Memangkas semua cache builder Docker..."
            docker builder prune -a -f
            echo -e "  ${SUCCESS_PREFIX} Semua cache builder Docker telah dipangkas."
        else
            echo -e "  ${SKIPPED_PREFIX} Pemangkasan semua cache builder Docker dilewati oleh pengguna."
        fi
        echo
        echo -e "  ${SUCCESS_PREFIX} Pembersihan Docker selesai."
    else
        echo -e "  ${SKIPPED_PREFIX} Perintah docker tidak ditemukan. Melewati pembersihan Docker."
    fi
    press_enter_to_continue
}

# --- Sub Menu Utilitas Sistem ---
submenu_system_utilities() {
    while true; do
        clear
        show_ascii_art # Tampilkan header di setiap tampilan submenu
        echo -e "  ╭────────────────────────────────────────────────────╮"
        echo -e "  │ ${BOLD_WHITE}Utilitas Sistem${DEFAULT_COLOR}                                  │"
        echo -e "  ├────────────────────────────────────────────────────┤"
        echo -e "  │ ${BOLD_YELLOW}1.${DEFAULT_COLOR} Analisis Penggunaan Disk                         │"
        echo -e "  │ ${BOLD_YELLOW}2.${DEFAULT_COLOR} Tinjau Log Sistem Penting                      │"
        echo -e "  │ ${BOLD_YELLOW}0.${DEFAULT_COLOR} ${BOLD_RED}Kembali ke Menu Utama${DEFAULT_COLOR}                       │"
        echo -e "  ╰────────────────────────────────────────────────────╯"
        read -p "$(echo -e "  ${BOLD_WHITE}Masukkan pilihan Anda [0-2]: ${DEFAULT_COLOR}")" util_choice

        case $util_choice in
            1) clear; analyze_disk_usage ;;
            2) clear; review_system_logs ;;
            0) break ;;
            *) echo -e "  ${ERROR_PREFIX} Pilihan tidak valid." ; sleep 2 ;;
        esac
    done
}

# Fitur Baru: Analisis Penggunaan Disk
analyze_disk_usage() {
    echo
    echo -e "  ${INFO_PREFIX} Menganalisis penggunaan disk..."
    echo -e "  ${CYAN}Penggunaan disk keseluruhan:${DEFAULT_COLOR}"
    df -h | sed 's/^/    /' # Tambahkan indentasi
    echo
    echo -e "  ${CYAN}10 direktori teratas berdasarkan penggunaan di / (mungkin memakan waktu):${DEFAULT_COLOR}"
    du -ahx / 2>/dev/null | sort -rh | head -n 10 | sed 's/^/    /' # Tambahkan indentasi
    echo
    read -p "$(echo -e "  ${QUESTION_PREFIX} Masukkan path direktori spesifik untuk dianalisis (kosongkan untuk kembali): ")" specific_path
    if [ -n "$specific_path" ]; then
        if [ -d "$specific_path" ]; then
            echo -e "  ${CYAN}Penggunaan disk untuk ${specific_path}:${DEFAULT_COLOR}"
            du -sh "$specific_path"/* 2>/dev/null | sort -rh | head -n 20 | sed 's/^/    /' # Tambahkan indentasi
        else
            echo -e "  ${ERROR_PREFIX} Direktori tidak ditemukan: $specific_path"
        fi
    fi
    press_enter_to_continue
}

# Fitur Baru: Tinjau Log Sistem
review_system_logs() {
    echo
    echo -e "  ${INFO_PREFIX} Meninjau log sistem penting..."
    local log_file
    local num_lines=20

    PS3="$(echo -e "  ${QUESTION_PREFIX}Pilih file log untuk ditinjau (atau 0 untuk kembali): ${DEFAULT_COLOR}")"
    options=("/var/log/syslog" "/var/log/auth.log" "/var/log/kern.log" "/var/log/dpkg.log" "Masukkan path log kustom" "Kembali")
    
    # Menu select butuh indentasi agar selaras
    echo # Baris kosong sebelum menu select
    COLUMNS=1 # Agar select ditampilkan satu kolom
    select opt in "${options[@]}"
    do
        # Indentasi pilihan menu
        REPLY_INDENTED="    $REPLY"

        case $opt in
            "/var/log/syslog") log_file="/var/log/syslog"; break;;
            "/var/log/auth.log") log_file="/var/log/auth.log"; break;;
            "/var/log/kern.log") log_file="/var/log/kern.log"; break;;
            "/var/log/dpkg.log") log_file="/var/log/dpkg.log"; break;;
            "Masukkan path log kustom")
                read -p "$(echo -e "  ${QUESTION_PREFIX}Masukkan path lengkap ke file log: ${DEFAULT_COLOR}")" custom_log_file
                if [ -f "$custom_log_file" ]; then
                    log_file="$custom_log_file"
                else
                    echo -e "  ${ERROR_PREFIX} File log kustom tidak ditemukan: $custom_log_file"
                    log_file=""
                fi
                break;;
            "Kembali") clear; return;; # Kembali dan bersihkan layar dari menu select
            *) echo -e "  ${ERROR_PREFIX} Pilihan tidak valid $REPLY_INDENTED";;
        esac
    done </dev/tty # Pastikan select membaca dari terminal interaktif

    if [ -n "$log_file" ] && [ -f "$log_file" ]; then
        read -p "$(echo -e "  ${QUESTION_PREFIX}Berapa banyak baris terakhir yang ingin Anda lihat (default: $num_lines)? ${DEFAULT_COLOR}")" lines_input
        if [[ "$lines_input" =~ ^[0-9]+$ ]]; then
            num_lines="$lines_input"
        fi
        echo -e "  ${CYAN}Menampilkan ${num_lines} baris terakhir dari ${log_file}:${DEFAULT_COLOR}"
        tail -n "$num_lines" "$log_file" | sed 's/^/    /' # Tambahkan indentasi
        echo
    elif [ -n "$log_file" ]; then
        echo -e "  ${ERROR_PREFIX} Tidak dapat menampilkan log: $log_file"
    fi
    press_enter_to_continue
}


# Fungsi untuk menjalankan semua tugas pembersihan
run_all_cleanup() {
    clear
    show_ascii_art
    echo
    echo -e "  ${INFO_PREFIX} Menjalankan SEMUA tugas pembersihan yang dipilih..."
    echo -e "  ${WARNING_PREFIX} Beberapa tindakan bersifat destruktif dan akan memerlukan konfirmasi individual."
    read -p "$(echo -e "  ${QUESTION_PREFIX} Anda yakin ingin melanjutkan dengan SEMUA tugas pembersihan? (${BOLD_GREEN}yes${DEFAULT_COLOR}/${BOLD_RED}NO${DEFAULT_COLOR}): ")" confirm_all
    if [[ "$confirm_all" == "yes" ]]; then
        clean_apt # Akan memanggil press_enter_to_continue di dalamnya
        clear; show_ascii_art; # Bersihkan dan tampilkan header lagi
        # remove_specific_packages
        clean_var_log
        clear; show_ascii_art;
        configure_clean_journald
        clear; show_ascii_art;
        clean_tmp_files
        clear; show_ascii_art;
        clean_user_cache
        clear; show_ascii_art;
        echo -e "  ${INFO_PREFIX} Menjalankan pembersihan cache aplikasi..."
        clean_npm_cache
        clear; show_ascii_art;
        clean_pip3_cache
        clear; show_ascii_art;
        clean_go_cache
        clear; show_ascii_art;
        clean_maven_cache
        clear; show_ascii_art;
        clean_gradle_cache
        clear; show_ascii_art;
        clean_docker
        echo -e "  ${SUCCESS_PREFIX} SEMUA tugas pembersihan yang dipilih telah dijalankan (sesuai konfirmasi individual)."
    else
        echo -e "  ${SKIPPED_PREFIX} Operasi 'Jalankan Semua' dibatalkan oleh pengguna."
    fi
    press_enter_to_continue
}


# --- Menu Utama ---
show_main_menu() {
    clear
    show_ascii_art
    echo -e "  ╭───────────────────────────────────────────────────────────╮"
    echo -e "  │ ${BOLD_WHITE}Pilih opsi pembersihan atau utilitas:${DEFAULT_COLOR}                     │"
    echo -e "  ├───────────────────────────────────────────────────────────┤"
    echo -e "  │ ${BOLD_YELLOW}Pembersihan Sistem Umum:${DEFAULT_COLOR}                                  │"
    echo -e "  │   ${BOLD_YELLOW}1.${DEFAULT_COLOR} Bersihkan Cache Apt-get                              │"
    echo -e "  │   ${BOLD_YELLOW}2.${DEFAULT_COLOR} Hapus Paket Tertentu                                 │"
    echo -e "  │   ${BOLD_YELLOW}3.${DEFAULT_COLOR} Bersihkan Log Lama (/var/log)                        │"
    echo -e "  │   ${BOLD_YELLOW}4.${DEFAULT_COLOR} Konfigurasi & Bersihkan Journald (Systemd Logs)      │"
    echo -e "  │   ${BOLD_YELLOW}5.${DEFAULT_COLOR} Hapus File Sementara (/tmp)                          │"
    echo -e "  │   ${BOLD_YELLOW}6.${DEFAULT_COLOR} Bersihkan Cache Pengguna (~/.cache)                  │"
    echo -e "  │   ${BOLD_YELLOW}7.${DEFAULT_COLOR} Pembersihan Cache Aplikasi (NPM, Pip, Go, dll.)      │"
    echo -e "  │   ${BOLD_YELLOW}8.${DEFAULT_COLOR} Pembersihan Docker Lengkap                           │"
    echo -e "  │   ${BOLD_YELLOW}9.${DEFAULT_COLOR} Utilitas Sistem (Analisis Disk, Tinjau Log)          │"
    echo -e "  ├───────────────────────────────────────────────────────────┤"
    echo -e "  │ ${BOLD_GREEN}13. JALANKAN SEMUA Tugas Pembersihan Utama${DEFAULT_COLOR}                │"
    echo -e "  │ ${BOLD_RED} 0. Keluar${DEFAULT_COLOR}                                                │"
    echo -e "  ╰───────────────────────────────────────────────────────────╯"
}

# Loop utama untuk menu
while true; do
    show_main_menu
    read -p "$(echo -e "  ${BOLD_WHITE}Masukkan pilihan Anda [0-9, 13]: ${DEFAULT_COLOR}")" choice
    
    # Tambahkan clear sebelum memanggil fungsi agar tampilan lebih bersih
    case $choice in
        1) clear; clean_apt ;;
        2) clear; remove_specific_packages ;;
        3) clear; clean_var_log ;;
        4) clear; configure_clean_journald ;;
        5) clear; clean_tmp_files ;;
        6) clear; clean_user_cache ;;
        7) submenu_app_cache_cleanup ;; # Submenu sudah menghandle clear & show_ascii_art
        8) clear; clean_docker ;;
        9) submenu_system_utilities ;; # Submenu sudah menghandle clear & show_ascii_art
        13) run_all_cleanup ;; # run_all_cleanup sudah menghandle clear & show_ascii_art
        0) echo -e "  ${BOLD_GREEN}Keluar dari skrip pembersihan. Sampai jumpa!${DEFAULT_COLOR}"; break ;;
        *) echo -e "  ${ERROR_PREFIX} Pilihan tidak valid. Silakan coba lagi." ; sleep 2 ;;
    esac
done

echo
echo -e "  ${BOLD_MAGENTA}=======================================${DEFAULT_COLOR}"
echo -e "  ${BOLD_GREEN}Skrip Pembersihan Server Linux Selesai.${DEFAULT_COLOR}"
echo -e "  ${YELLOW}Tinjau output di atas untuk setiap kesalahan atau langkah yang dilewati.${DEFAULT_COLOR}"
echo