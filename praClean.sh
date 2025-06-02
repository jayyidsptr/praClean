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
AI_PREFIX="${BOLD_MAGENTA}[AI GEMINI]${DEFAULT_COLOR}"

# Variabel Global untuk AI
GEMINI_API_KEY=""
AI_DEPENDENCIES_MET=0
GLOW_INSTALLED=0 # Flag untuk glow
GEMINI_API_ENDPOINT="https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash-latest:generateContent"

# --- Fungsi Animasi Loading ---
show_loading_animation() {
    local duration=1
    local spinstr='|/-\\'
    local delay=0.1
    local end_time=$((SECONDS + duration))

    echo
    tput civis # Sembunyikan kursor
    while [ $SECONDS -lt $end_time ]; do
        local temp=${spinstr#?}
        printf "  ${BOLD_CYAN}Memuat PRA CLEAN Utility %c ${DEFAULT_COLOR}" "$spinstr"
        spinstr=$temp${spinstr%"$temp"}
        sleep $delay
        printf "\r" # Kembali ke awal baris
    done
    printf "                                        \r" # Hapus baris animasi
    tput cnorm # Tampilkan kursor kembali
    echo
}

# --- Fungsi AI Gemini ---

check_ai_dependencies() {
    local all_met=1
    if ! command -v curl &> /dev/null; then
        echo -e "  ${YELLOW}Fitur AI memerlukan 'curl'. Mohon install (contoh: sudo apt install curl)${DEFAULT_COLOR}"
        all_met=0
    fi
    if ! command -v jq &> /dev/null; then
        echo -e "  ${YELLOW}Fitur AI memerlukan 'jq'. Mohon install (contoh: sudo apt install jq)${DEFAULT_COLOR}"
        all_met=0
    fi

    if [ "$all_met" -eq 1 ]; then
        AI_DEPENDENCIES_MET=1
    else
        AI_DEPENDENCIES_MET=0
        echo -e "  ${WARNING_PREFIX} Beberapa dependensi dasar AI tidak terpenuhi. Fitur AI mungkin tidak berfungsi."
        press_enter_to_continue
    fi

    if command -v glow &> /dev/null; then
        GLOW_INSTALLED=1
    else
        GLOW_INSTALLED=0
        echo -e "  ${INFO_PREFIX} Untuk tampilan respons AI yang lebih baik, disarankan menginstal 'glow'."
        echo -e "  ${CYAN}(Kunjungi: https://github.com/charmbracelet/glow)${DEFAULT_COLOR}"
    fi
}

get_gemini_api_key() {
    if [ -n "$GEMINI_API_KEY" ]; then return 0; fi
    if [ -n "$PRA_CLEAN_GEMINI_API_KEY" ]; then
        GEMINI_API_KEY="$PRA_CLEAN_GEMINI_API_KEY"; return 0
    fi
    
    echo -e "  ${INFO_PREFIX} Fitur AI Gemini memerlukan API Key."
    echo -e "  ${CYAN}Dapatkan dari Google AI Studio: https://aistudio.google.com/app/apikey ${DEFAULT_COLOR}"
    echo -e "  ${YELLOW}Disarankan mengatur variabel environment 'PRA_CLEAN_GEMINI_API_KEY'.${DEFAULT_COLOR}"
    read -s -p "$(echo -e "  ${QUESTION_PREFIX} Masukkan API Key Gemini (kosongkan untuk melewati): ")" key_input
    echo
    if [ -n "$key_input" ]; then
        GEMINI_API_KEY="$key_input"
        echo -e "  ${INFO_PREFIX} API Key Gemini disimpan untuk sesi ini."
    else
        echo -e "  ${SKIPPED_PREFIX} Tidak ada API Key. Fitur AI akan dilewati."; GEMINI_API_KEY=""
    fi
}

# Fungsi generik untuk berinteraksi dengan AI Gemini
# Argumen 1: Teks prompt lengkap untuk AI
ask_ai_gemini() {
    local prompt_text="$1"

    if [ "$AI_DEPENDENCIES_MET" -eq 0 ]; then
        echo -e "  ${ERROR_PREFIX} Dependensi dasar AI (curl/jq) tidak terpenuhi."
        return 1
    fi
    if [ -z "$GEMINI_API_KEY" ]; then
        get_gemini_api_key
        if [ -z "$GEMINI_API_KEY" ]; then
            echo -e "  ${SKIPPED_PREFIX} Tidak ada API Key Gemini. Tugas AI dilewati."
            return 1
        fi
    fi

    echo -e "  ${INFO_PREFIX} Menghubungi AI Gemini (mungkin perlu beberapa saat)..."
    tput civis

    local json_payload
    json_payload=$(jq -n \
                  --arg prompt "$prompt_text" \
                  '{ "contents": [ { "parts": [ { "text": $prompt } ] } ],
                     "generationConfig": {
                       "temperature": 0.5, 
                       "maxOutputTokens": 2048 
                     } }')

    local response
    response=$(curl -s -X POST "${GEMINI_API_ENDPOINT}?key=${GEMINI_API_KEY}" \
              -H "Content-Type: application/json" \
              -d "$json_payload")
    tput cnorm

    if [ -z "$response" ]; then
        echo -e "  ${ERROR_PREFIX} Tidak ada respons dari API Gemini. Periksa koneksi internet."
        return 1
    fi
    if echo "$response" | jq -e '.error' > /dev/null; then
        local error_message
        error_message=$(echo "$response" | jq -r '.error.message')
        echo -e "  ${ERROR_PREFIX} API Gemini error: ${error_message}"
        return 1
    fi
    
    local explanation
    explanation=$(echo "$response" | jq -r '.candidates[0].content.parts[0].text // ""')

    if [[ -z "$explanation" ]]; then
        echo -e "  ${WARNING_PREFIX} AI Gemini tidak memberikan respons atau format tidak dikenal."
        return 1
    fi

    echo -e "\n  ${AI_PREFIX} Berikut respons dari AI Gemini:"
    echo -e "${CYAN}---------------------------------------------------------------------${DEFAULT_COLOR}"
    if [ "$GLOW_INSTALLED" -eq 1 ]; then
        echo -e "${explanation}" | glow -s dark -w "$(( $(tput cols) - 8 ))"
    else
        echo -e "${explanation}" | sed 's/^/    /'
    fi
    echo -e "${CYAN}---------------------------------------------------------------------${DEFAULT_COLOR}"
    return 0
}

# --- Pemeriksaan Hak Akses Root ---
check_sudo() {
    if [[ "$EUID" -ne 0 ]]; then
        echo -e "${WARNING_PREFIX} Skrip ini memerlukan hak akses root."
        echo -e "${INFO_PREFIX} Silakan jalankan ulang dengan sudo: sudo $0"; exit 1
    fi
}

# Panggil di awal
check_sudo
show_loading_animation
check_ai_dependencies

# Fungsi untuk menampilkan seni ASCII
show_ascii_art() {
echo -e "${BOLD_GREEN}"
cat << "EOF"
        PPPP   RRRR    AAA       CCCC  L      EEEEEE  AAA   NN   NN
        P   P  R   R  A   A     C      L      E      A   A  N N  N
        PPPP   RRRR   AAAAA     C      L      EEEE   AAAAA  N  N N
        P      R  R  A     A     C      L      E      A   A  N   NN
        P      R   R A       A   CCCC  LLLLL  EEEEEE A     A N    N
EOF
echo -e "${DEFAULT_COLOR}"
echo -e "${BOLD_MAGENTA}=======================================================================${DEFAULT_COLOR}"
echo -e "${BOLD_MAGENTA}                        PRA CLEAN UTILITY                             ${DEFAULT_COLOR}"
echo -e "${BOLD_MAGENTA}=======================================================================${DEFAULT_COLOR}"
echo -e "${CYAN}                        Developed by: jayyidsptr                       ${DEFAULT_COLOR}"
echo -e "${CYAN}                 https://github.com/jayyidsptr                      ${DEFAULT_COLOR}"
if [ "$AI_DEPENDENCIES_MET" -eq 1 ]; then
    if [ "$GLOW_INSTALLED" -eq 1 ]; then
        echo -e "${BLUE}          ✨ Fitur AI Gemini Aktif (Render dengan Glow) ✨         ${DEFAULT_COLOR}"
    else
        echo -e "${BLUE}                 ✨ Fitur AI Gemini Aktif ✨                      ${DEFAULT_COLOR}"
    fi
fi
echo
}

# --- Fungsi Utilitas ---
press_enter_to_continue() {
    echo 
    read -n 1 -s -r -p "$(echo -e "  ${YELLOW}Tekan Enter untuk kembali ke menu...${DEFAULT_COLOR}")"
}

# --- Fungsi Pembersihan ---

# 1. Pembersihan Apt-get
clean_apt() {
    echo; echo -e "  ${INFO_PREFIX} Membersihkan cache apt-get..."
    apt-get autoclean -y && apt-get clean -y
    echo -e "  ${INFO_PREFIX} Menghapus paket yang tidak terpakai (autoremove)..."
    apt-get autoremove -y
    echo -e "  ${SUCCESS_PREFIX} Pembersihan apt-get selesai."
    press_enter_to_continue
}

# 2. Hapus Paket Tertentu
remove_specific_packages() {
    echo; echo -e "  ${INFO_PREFIX} Menghapus perangkat lunak tertentu..."
    read -p "$(echo -e "  ${QUESTION_PREFIX} Masukkan nama paket (pisahkan spasi, kosongkan untuk batal): ")" packages_to_remove
    if [ -n "$packages_to_remove" ]; then
        if [ "$AI_DEPENDENCIES_MET" -eq 1 ]; then
            read -p "$(echo -e "  ${QUESTION_PREFIX} Info AI dampak hapus '${BOLD_YELLOW}${packages_to_remove}${DEFAULT_COLOR}'? (${BOLD_GREEN}Y${DEFAULT_COLOR}/n): ")" explain_pkg
            if [[ "$explain_pkg" =~ ^[Yy]$ ]]; then
                local prompt="Anda adalah AI asisten sistem Linux. Jelaskan fungsi utama paket Linux '$packages_to_remove', dependensi pentingnya, dan potensi risiko jika paket ini dihapus dari sistem server standar (misalnya Ubuntu Server). Berikan juga saran apakah umumnya aman untuk dihapus atau jika ada alternatif. Format dalam Markdown."
                ask_ai_gemini "$prompt"
            fi
        fi
        read -p "$(echo -e "  ${WARNING_PREFIX} YAKIN hapus '${BOLD_RED}${packages_to_remove}${DEFAULT_COLOR}'? (${BOLD_GREEN}yes${DEFAULT_COLOR}/${BOLD_RED}NO${DEFAULT_COLOR}): ")" confirm_remove_pkg
        if [[ "$confirm_remove_pkg" == "yes" ]]; then
            # shellcheck disable=SC2086
            apt-get remove $packages_to_remove -y
            echo -e "  ${SUCCESS_PREFIX} Penghapusan paket '${packages_to_remove}' selesai."
        else echo -e "  ${SKIPPED_PREFIX} Penghapusan paket '${packages_to_remove}' dibatalkan."; fi
    else echo -e "  ${SKIPPED_PREFIX} Tidak ada paket yang ditentukan."; fi
    press_enter_to_continue
}

# 3. Bersihkan Log Lama (/var/log)
clean_var_log() {
    echo; local perintah_log_desc="membersihkan isi /var/log"
    local perintah_log_cmd="find /var/log -mindepth 1 -depth -delete"
    echo -e "  ${INFO_PREFIX} Membersihkan log lama di /var/log..."
    echo -e "  ${WARNING_PREFIX} Ini akan menghapus SEMUA konten di /var/log (kecuali file aktif)."
    echo -e "  ${YELLOW}Periksa file besar dulu: cd /var/log && du -h . | sort -hr | head -n 10${DEFAULT_COLOR}"
    if [ "$AI_DEPENDENCIES_MET" -eq 1 ]; then
        read -p "$(echo -e "  ${QUESTION_PREFIX} Penjelasan AI tentang ${perintah_log_desc}? (${BOLD_GREEN}Y${DEFAULT_COLOR}/n): ")" explain_choice
        if [[ "$explain_choice" =~ ^[Yy]$ ]]; then
            local prompt="Anda adalah AI asisten sistem Linux. Jelaskan perintah '$perintah_log_cmd'. Fokus pada: apa yang dilakukannya, file/direktori terdampak, potensi risiko (misalnya kehilangan log penting jika belum di-backup), dan apakah ini praktik umum yang aman. Format dalam Markdown."
            ask_ai_gemini "$prompt"
        fi
    fi
    read -p "$(echo -e "  ${QUESTION_PREFIX} Lanjutkan menghapus isi /var/log? (${BOLD_GREEN}yes${DEFAULT_COLOR}/${BOLD_RED}NO${DEFAULT_COLOR}): ")" confirm_var_log
    if [[ "$confirm_var_log" == "yes" ]]; then
        find /var/log -mindepth 1 -depth -print0 | xargs -0 --no-run-if-empty rm -rf
        echo -e "  ${SUCCESS_PREFIX} Konten /var/log dibersihkan."
    else echo -e "  ${SKIPPED_PREFIX} Pembersihan /var/log dilewati."; fi
    press_enter_to_continue
}

# 4. Konfigurasi dan Bersihkan Journald
configure_clean_journald() {
    echo; echo -e "  ${INFO_PREFIX} Mengkonfigurasi & membersihkan systemd journald..."
    # (Implementasi fungsi ini tetap sama seperti sebelumnya, dengan opsi AI untuk menjelaskan perintah journalctl)
    # ... (kode dari versi sebelumnya untuk configure_clean_journald dengan sedikit penyesuaian prompt AI jika perlu)
    local current_max_use; current_max_use=$(grep -Po '^SystemMaxUse=\K[^ ]+' /etc/systemd/journald.conf 2>/dev/null || echo "Tidak diatur")
    local current_max_file_size; current_max_file_size=$(grep -Po '^SystemMaxFileSize=\K[^ ]+' /etc/systemd/journald.conf 2>/dev/null || echo "Tidak diatur")
    echo -e "  ${CYAN}Konfigurasi saat ini: SystemMaxUse=${BOLD_YELLOW}${current_max_use}${DEFAULT_COLOR}, SystemMaxFileSize=${BOLD_YELLOW}${current_max_file_size}${DEFAULT_COLOR}${DEFAULT_COLOR}"
    read -p "$(echo -e "  ${QUESTION_PREFIX} Ubah konfigurasi ukuran log journald? (${BOLD_GREEN}y${DEFAULT_COLOR}/N): ")" change_conf
    if [[ "$change_conf" =~ ^[Yy]$ ]]; then
        read -p "$(echo -e "  ${QUESTION_PREFIX} SystemMaxUse (cth: 1G, kosongkan untuk tidak mengubah): ")" new_max_use
        read -p "$(echo -e "  ${QUESTION_PREFIX} SystemMaxFileSize (cth: 50M, kosongkan untuk tidak mengubah): ")" new_max_file_size
        if [ -f /etc/systemd/journald.conf ]; then
            if [ -n "$new_max_use" ]; then
                if grep -q "^SystemMaxUse=" /etc/systemd/journald.conf; then sed -i "s/^SystemMaxUse=.*/SystemMaxUse=${new_max_use}/" /etc/systemd/journald.conf; else sed -i '/\[Journal\]/a SystemMaxUse='"${new_max_use}" /etc/systemd/journald.conf; fi
                echo -e "  ${INFO_PREFIX} SystemMaxUse diatur ke ${new_max_use}."
            fi
            if [ -n "$new_max_file_size" ]; then
                if grep -q "^SystemMaxFileSize=" /etc/systemd/journald.conf; then sed -i "s/^SystemMaxFileSize=.*/SystemMaxFileSize=${new_max_file_size}/" /etc/systemd/journald.conf; else sed -i '/\[Journal\]/a SystemMaxFileSize='"${new_max_file_size}" /etc/systemd/journald.conf; fi
                echo -e "  ${INFO_PREFIX} SystemMaxFileSize diatur ke ${new_max_file_size}."
            fi
            if [ -n "$new_max_use" ] || [ -n "$new_max_file_size" ]; then
                 echo -e "  ${INFO_PREFIX} Merestart systemd-journald..."; systemctl restart systemd-journald
            else echo -e "  ${INFO_PREFIX} Tidak ada perubahan konfigurasi."; fi
        else echo -e "  ${WARNING_PREFIX} /etc/systemd/journald.conf tidak ditemukan."; fi
    fi; echo
    echo -e "  ${INFO_PREFIX} Membersihkan log systemd journal..."
    read -p "$(echo -e "  ${QUESTION_PREFIX} Bersihkan log berdasarkan waktu? (cth: 2d, kosongkan): ")" vacuum_time
    if [ -n "$vacuum_time" ]; then
        local cmd_explain="journalctl --vacuum-time=${vacuum_time}"
        if [ "$AI_DEPENDENCIES_MET" -eq 1 ]; then
            read -p "$(echo -e "  ${QUESTION_PREFIX} Penjelasan AI untuk '${BOLD_YELLOW}${cmd_explain}${DEFAULT_COLOR}'? (${BOLD_GREEN}Y${DEFAULT_COLOR}/n): ")" explain_ai
            if [[ "$explain_ai" =~ ^[Yy]$ ]]; then ask_ai_gemini "Jelaskan perintah Linux '$cmd_explain' untuk membersihkan log journald berdasarkan waktu. Fokus pada apa yang dilakukannya dan dampaknya. Format Markdown."; fi
        fi
        eval "$cmd_explain" # Gunakan eval jika variabel mengandung opsi
        echo -e "  ${INFO_PREFIX} Log journald > ${vacuum_time} dibersihkan."
    fi
    read -p "$(echo -e "  ${QUESTION_PREFIX} Bersihkan log berdasarkan ukuran? (cth: 100M, kosongkan): ")" vacuum_size
    if [ -n "$vacuum_size" ]; then
        local cmd_explain="journalctl --vacuum-size=${vacuum_size}"
        if [ "$AI_DEPENDENCIES_MET" -eq 1 ]; then
            read -p "$(echo -e "  ${QUESTION_PREFIX} Penjelasan AI untuk '${BOLD_YELLOW}${cmd_explain}${DEFAULT_COLOR}'? (${BOLD_GREEN}Y${DEFAULT_COLOR}/n): ")" explain_ai
            if [[ "$explain_ai" =~ ^[Yy]$ ]]; then ask_ai_gemini "Jelaskan perintah Linux '$cmd_explain' untuk membersihkan log journald berdasarkan ukuran. Fokus pada apa yang dilakukannya dan dampaknya. Format Markdown."; fi
        fi
        eval "$cmd_explain"
        echo -e "  ${INFO_PREFIX} Log journald dibatasi hingga ${vacuum_size}."
    fi
    echo -e "  ${SUCCESS_PREFIX} Pembersihan & konfigurasi Journald selesai."
    press_enter_to_continue
}

# 5. Hapus File Sementara (/tmp)
clean_tmp_files() {
    # (Implementasi fungsi ini tetap sama seperti sebelumnya, dengan opsi AI)
    echo; local cmd_tmp_desc="membersihkan /tmp"
    local cmd_tmp_actual="find /tmp -mindepth 1 -delete"
    echo -e "  ${INFO_PREFIX} Membersihkan file sementara di /tmp..."
    echo -e "  ${WARNING_PREFIX} Ini akan menghapus semua konten di /tmp."
    if [ "$AI_DEPENDENCIES_MET" -eq 1 ]; then
        read -p "$(echo -e "  ${QUESTION_PREFIX} Penjelasan AI tentang dampak ${cmd_tmp_desc}? (${BOLD_GREEN}Y${DEFAULT_COLOR}/n): ")" explain_tmp_cmd
        if [[ "$explain_tmp_cmd" =~ ^[Yy]$ ]]; then 
            ask_ai_gemini "Anda adalah AI asisten sistem Linux. Jelaskan perintah '$cmd_tmp_actual' untuk membersihkan isi direktori /tmp. Fokus pada: apa yang dilakukannya, mengapa /tmp digunakan, risiko menghapus isinya (misalnya jika ada aplikasi aktif yang menggunakan file di sana), dan apakah ini praktik umum yang aman. Format dalam Markdown."
        fi
    fi
    read -p "$(echo -e "  ${QUESTION_PREFIX} Lanjutkan menghapus semua file di /tmp? (${BOLD_GREEN}yes${DEFAULT_COLOR}/${BOLD_RED}NO${DEFAULT_COLOR}): ")" confirm_tmp
    if [[ "$confirm_tmp" == "yes" ]]; then
        find /tmp -mindepth 1 -delete
        echo -e "  ${SUCCESS_PREFIX} File sementara di /tmp telah dibersihkan."
    else echo -e "  ${SKIPPED_PREFIX} Pembersihan /tmp dilewati."; fi
    press_enter_to_continue
}

# 6. Bersihkan Cache Pengguna (~/.cache)
clean_user_cache() {
    # (Implementasi fungsi ini tetap sama seperti sebelumnya, dengan opsi AI)
    echo
    local user_home; user_home=$(getent passwd "$SUDO_USER" | cut -d: -f6)
    local user_cache_dir="$user_home/.cache"
    if [ -z "$user_home" ] || [ ! -d "$user_cache_dir" ]; then
        echo -e "  ${WARNING_PREFIX} Tidak dapat menemukan cache untuk $SUDO_USER ($user_cache_dir). Melewati."
        press_enter_to_continue; return
    fi
    echo -e "  ${INFO_PREFIX} Membersihkan cache pengguna (${BOLD_YELLOW}${user_cache_dir}${DEFAULT_COLOR})..."
    echo -e "  ${CYAN}10 item terbesar di ${user_cache_dir}:${DEFAULT_COLOR}"
    sudo -u "$SUDO_USER" du -sh "$user_cache_dir"/* 2>/dev/null | sort -hr | head -n 10
    echo -e "  ${WARNING_PREFIX} Ini akan menghapus semua file di ${user_cache_dir}."
    if [ "$AI_DEPENDENCIES_MET" -eq 1 ]; then
        read -p "$(echo -e "  ${QUESTION_PREFIX} Penjelasan AI tentang dampak membersihkan ${user_cache_dir}? (${BOLD_GREEN}Y${DEFAULT_COLOR}/n): ")" explain_user_cache_cmd
        if [[ "$explain_user_cache_cmd" =~ ^[Yy]$ ]]; then 
            ask_ai_gemini "Anda adalah AI asisten sistem Linux. Jelaskan dampak dari membersihkan direktori '$user_cache_dir' untuk pengguna '$SUDO_USER'. Apa saja jenis data yang biasanya disimpan di sana? Apakah aman untuk menghapusnya? Apakah akan ada efek samping (misalnya aplikasi perlu membuat ulang cache)? Format dalam Markdown."
        fi
    fi
    read -p "$(echo -e "  ${QUESTION_PREFIX} Lanjutkan menghapus semua file di ${user_cache_dir}? (${BOLD_GREEN}yes${DEFAULT_COLOR}/${BOLD_RED}NO${DEFAULT_COLOR}): ")" confirm_user_cache
    if [[ "$confirm_user_cache" == "yes" ]]; then
        sudo -u "$SUDO_USER" find "$user_cache_dir" -mindepth 1 -delete
        echo -e "  ${SUCCESS_PREFIX} Cache pengguna (${user_cache_dir}) telah dibersihkan."
    else echo -e "  ${SKIPPED_PREFIX} Pembersihan ${user_cache_dir} dilewati."; fi
    press_enter_to_continue
}

# --- Sub Menu Pembersihan Cache Aplikasi ---
submenu_app_cache_cleanup() {
    # (Implementasi fungsi ini tetap sama)
    while true; do
        clear; show_ascii_art 
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
        read -p "$(echo -e "  ${BOLD_WHITE}Pilihan Anda [0-5]: ${DEFAULT_COLOR}")" app_cache_choice
        case $app_cache_choice in
            1) clear; clean_npm_cache ;; 2) clear; clean_pip3_cache ;; 3) clear; clean_go_cache ;;
            4) clear; clean_maven_cache ;; 5) clear; clean_gradle_cache ;; 0) break ;;
            *) echo -e "  ${ERROR_PREFIX} Pilihan tidak valid." ; sleep 2 ;;
        esac
    done
}
# (Fungsi clean_npm_cache, clean_pip3_cache, dst. tetap sama)
clean_npm_cache() {
    echo; echo -e "  ${INFO_PREFIX} Membersihkan cache NPM..."
    if command -v npm &> /dev/null; then
        if [ -n "$SUDO_USER" ] && [ "$SUDO_USER" != "root" ]; then
             sudo -u "$SUDO_USER" npm cache clean --force && sudo -u "$SUDO_USER" npm cache verify
        else npm cache clean --force && npm cache verify; fi
        echo -e "  ${SUCCESS_PREFIX} Pembersihan cache NPM selesai."
    else echo -e "  ${SKIPPED_PREFIX} npm tidak ditemukan."; fi
    press_enter_to_continue
}
clean_pip3_cache() {
    echo; echo -e "  ${INFO_PREFIX} Membersihkan cache Pip3..."
    if command -v pip3 &> /dev/null; then
        echo -e "  ${CYAN}Info cache Pip3:${DEFAULT_COLOR}"
        if [ -n "$SUDO_USER" ] && [ "$SUDO_USER" != "root" ]; then
            sudo -u "$SUDO_USER" pip3 cache info && sudo -u "$SUDO_USER" pip3 cache purge
        else pip3 cache info && pip3 cache purge; fi
        echo -e "  ${SUCCESS_PREFIX} Pembersihan cache Pip3 selesai."
    else echo -e "  ${SKIPPED_PREFIX} pip3 tidak ditemukan."; fi
    press_enter_to_continue
}
clean_go_cache() {
    echo; echo -e "  ${INFO_PREFIX} Membersihkan cache Go..."
    if command -v go &> /dev/null; then
        local go_user="${SUDO_USER:-root}"
        local GOCACHE_DIR; GOCACHE_DIR=$(sudo -u "$go_user" go env GOCACHE 2>/dev/null)
        if [ -n "$GOCACHE_DIR" ] && [ -d "$GOCACHE_DIR" ]; then
            echo -e "  ${CYAN}Ukuran cache Go ($GOCACHE_DIR):${DEFAULT_COLOR}"; sudo -u "$go_user" du -sh "$GOCACHE_DIR"
            sudo -u "$go_user" go clean -cache && sudo -u "$go_user" go clean -modcache
            echo -e "  ${SUCCESS_PREFIX} Pembersihan cache Go selesai."
        else echo -e "  ${SKIPPED_PREFIX} Cache Go tidak ditemukan untuk $go_user."; fi
    else echo -e "  ${SKIPPED_PREFIX} go tidak ditemukan."; fi
    press_enter_to_continue
}
clean_maven_cache() {
    echo; echo -e "  ${INFO_PREFIX} Membersihkan cache Maven..."
    local user_m2_repo="${SUDO_USER:-root}" 
    user_m2_repo_path="$(getent passwd "$user_m2_repo" | cut -d: -f6)/.m2/repository"
    if [ -d "$user_m2_repo_path" ]; then
        echo -e "  ${INFO_PREFIX} Membersihkan ${BOLD_YELLOW}${user_m2_repo_path}${DEFAULT_COLOR}..."
        echo -e "  ${WARNING_PREFIX} Ini akan menghapus repositori Maven."
        read -p "$(echo -e "  ${QUESTION_PREFIX} Lanjutkan? (${BOLD_GREEN}yes${DEFAULT_COLOR}/${BOLD_RED}NO${DEFAULT_COLOR}): ")" confirm_maven
        if [[ "$confirm_maven" == "yes" ]]; then
            sudo -u "$user_m2_repo" rm -rf "$user_m2_repo_path"
            echo -e "  ${SUCCESS_PREFIX} Cache Maven dibersihkan."
        else echo -e "  ${SKIPPED_PREFIX} Pembersihan cache Maven dilewati."; fi
    else echo -e "  ${SKIPPED_PREFIX} ${user_m2_repo_path} tidak ditemukan."; fi
    press_enter_to_continue
}
clean_gradle_cache() {
    echo; echo -e "  ${INFO_PREFIX} Membersihkan cache Gradle..."
    local user_gradle_cache="${SUDO_USER:-root}"
    user_gradle_cache_path="$(getent passwd "$user_gradle_cache" | cut -d: -f6)/.gradle/caches"
    if [ -d "$user_gradle_cache_path" ]; then
        echo -e "  ${INFO_PREFIX} Membersihkan ${BOLD_YELLOW}${user_gradle_cache_path}${DEFAULT_COLOR}..."
        if command -v gradle &> /dev/null; then
            echo -e "  ${INFO_PREFIX} Mencoba menghentikan daemon Gradle..."; sudo -u "$user_gradle_cache" gradle --stop > /dev/null 2>&1
        fi
        echo -e "  ${WARNING_PREFIX} Ini akan menghapus cache Gradle."
        read -p "$(echo -e "  ${QUESTION_PREFIX} Lanjutkan? (${BOLD_GREEN}yes${DEFAULT_COLOR}/${BOLD_RED}NO${DEFAULT_COLOR}): ")" confirm_gradle
        if [[ "$confirm_gradle" == "yes" ]]; then
            sudo -u "$user_gradle_cache" rm -rf "$user_gradle_cache_path"
            echo -e "  ${SUCCESS_PREFIX} Cache Gradle dibersihkan."
        else echo -e "  ${SKIPPED_PREFIX} Pembersihan cache Gradle dilewati."; fi
    else echo -e "  ${SKIPPED_PREFIX} ${user_gradle_cache_path} tidak ditemukan."; fi
    press_enter_to_continue
}

# 12. Pembersihan Docker
clean_docker() {
    # (Implementasi fungsi ini tetap sama seperti sebelumnya, dengan opsi AI untuk menjelaskan docker system prune -a)
    echo; echo -e "  ${INFO_PREFIX} Memulai Pembersihan Docker..."
    if ! command -v docker &> /dev/null; then
        echo -e "  ${SKIPPED_PREFIX} docker tidak ditemukan."; press_enter_to_continue; return
    fi
    echo -e "  ${CYAN}Ukuran direktori Docker (/var/lib/docker):${DEFAULT_COLOR}"; du -sh /var/lib/docker; echo
    local cmd_docker_system_prune_a="docker system prune -a -f"
    echo -e "  ${INFO_PREFIX} Perintah Docker berdampak besar: '${BOLD_YELLOW}${cmd_docker_system_prune_a}${DEFAULT_COLOR}'."
    if [ "$AI_DEPENDENCIES_MET" -eq 1 ]; then
        read -p "$(echo -e "  ${QUESTION_PREFIX} Penjelasan AI untuk '${BOLD_YELLOW}${cmd_docker_system_prune_a}${DEFAULT_COLOR}'? (${BOLD_GREEN}Y${DEFAULT_COLOR}/n): ")" explain_docker_cmd
        if [[ "$explain_docker_cmd" =~ ^[Yy]$ ]]; then 
            ask_ai_gemini "Anda adalah AI asisten sistem Linux. Jelaskan perintah '$cmd_docker_system_prune_a'. Fokus pada: apa saja yang dihapus (images, containers, volumes, networks, build cache), perbedaan dengan 'docker system prune' tanpa '-a', potensi risiko (kehilangan data jika tidak hati-hati), dan kapan sebaiknya digunakan. Format dalam Markdown."
        fi
    fi
    echo -e "  ${CYAN}Menampilkan Image Docker:${DEFAULT_COLOR}"; docker images -a; echo
    echo -e "  ${INFO_PREFIX} Memangkas image Docker menggantung..."; docker image prune -f; echo
    read -p "$(echo -e "  ${QUESTION_PREFIX} Pangkas SEMUA image Docker tak terpakai? (${BOLD_GREEN}yes${DEFAULT_COLOR}/${BOLD_RED}NO${DEFAULT_COLOR}): ")" confirm_prune_a
    if [[ "$confirm_prune_a" == "yes" ]]; then
        echo -e "  ${INFO_PREFIX} Memangkas semua image Docker tak terpakai..."; docker image prune -a -f
        echo -e "  ${SUCCESS_PREFIX} Semua image tak terpakai dipangkas."
    else echo -e "  ${SKIPPED_PREFIX} Pemangkasan semua image tak terpakai dilewati."; fi; echo
    echo -e "  ${INFO_PREFIX} Memangkas volume Docker tak terpakai..."; docker volume prune -f; echo
    echo -e "  ${INFO_PREFIX} Melakukan Docker system prune..."; docker system prune -f; echo
    read -p "$(echo -e "  ${WARNING_PREFIX} Lanjutkan dengan Docker system prune -a (SEMUA image tak terpakai & kontainer berhenti)? (${BOLD_GREEN}yes${DEFAULT_COLOR}/${BOLD_RED}NO${DEFAULT_COLOR}): ")" confirm_sys_prune_a
    if [[ "$confirm_sys_prune_a" == "yes" ]]; then
        echo -e "  ${INFO_PREFIX} Melakukan Docker system prune -a..."; docker system prune -a -f
        echo -e "  ${SUCCESS_PREFIX} Docker system prune -a selesai."
    else echo -e "  ${SKIPPED_PREFIX} Docker system prune -a dilewati."; fi; echo
    echo -e "  ${INFO_PREFIX} Memangkas cache builder Docker..."; docker builder prune -f; echo
    read -p "$(echo -e "  ${QUESTION_PREFIX} Pangkas SEMUA cache builder Docker? (${BOLD_GREEN}yes${DEFAULT_COLOR}/${BOLD_RED}NO${DEFAULT_COLOR}): ")" confirm_builder_prune_a
    if [[ "$confirm_builder_prune_a" == "yes" ]]; then
        echo -e "  ${INFO_PREFIX} Memangkas semua cache builder Docker..."; docker builder prune -a -f
        echo -e "  ${SUCCESS_PREFIX} Semua cache builder Docker dipangkas."
    else echo -e "  ${SKIPPED_PREFIX} Pemangkasan semua cache builder Docker dilewati."; fi; echo
    echo -e "  ${SUCCESS_PREFIX} Pembersihan Docker selesai."
    press_enter_to_continue
}

# --- Sub Menu Utilitas Sistem ---
submenu_system_utilities() {
    # (Implementasi fungsi ini tetap sama)
    while true; do
        clear; show_ascii_art 
        echo -e "  ╭────────────────────────────────────────────────────╮"
        echo -e "  │ ${BOLD_WHITE}Utilitas Sistem${DEFAULT_COLOR}                                  │"
        echo -e "  ├────────────────────────────────────────────────────┤"
        echo -e "  │ ${BOLD_YELLOW}1.${DEFAULT_COLOR} Analisis Penggunaan Disk ${CYAN}(AI Ready)${DEFAULT_COLOR}             │"
        echo -e "  │ ${BOLD_YELLOW}2.${DEFAULT_COLOR} Tinjau Log Sistem Penting ${CYAN}(AI Ready)${DEFAULT_COLOR}          │"
        echo -e "  │ ${BOLD_YELLOW}0.${DEFAULT_COLOR} ${BOLD_RED}Kembali ke Menu Utama${DEFAULT_COLOR}                       │"
        echo -e "  ╰────────────────────────────────────────────────────╯"
        read -p "$(echo -e "  ${BOLD_WHITE}Pilihan Anda [0-2]: ${DEFAULT_COLOR}")" util_choice
        case $util_choice in
            1) clear; analyze_disk_usage ;; 2) clear; review_system_logs ;; 0) break ;;
            *) echo -e "  ${ERROR_PREFIX} Pilihan tidak valid." ; sleep 2 ;;
        esac
    done
}

analyze_disk_usage() {
    echo; echo -e "  ${INFO_PREFIX} Menganalisis penggunaan disk..."
    echo -e "  ${CYAN}Penggunaan disk keseluruhan:${DEFAULT_COLOR}"; df -h | sed 's/^/    /'; echo
    echo -e "  ${CYAN}10 direktori teratas di / (mungkin lama):${DEFAULT_COLOR}"; du -ahx / 2>/dev/null | sort -rh | head -n 10 | sed 's/^/    /'; echo
    read -p "$(echo -e "  ${QUESTION_PREFIX} Analisis path spesifik (kosongkan untuk kembali): ")" specific_path
    if [ -n "$specific_path" ]; then
        if [ -d "$specific_path" ]; then
            echo -e "  ${CYAN}Penggunaan disk untuk ${specific_path}:${DEFAULT_COLOR}"
            du -sh "$specific_path"/* 2>/dev/null | sort -rh | head -n 20 | sed 's/^/    /'
            if [ "$AI_DEPENDENCIES_MET" -eq 1 ]; then
                read -p "$(echo -e "  ${QUESTION_PREFIX} Saran optimasi AI untuk ${BOLD_YELLOW}${specific_path}${DEFAULT_COLOR}? (${BOLD_GREEN}Y${DEFAULT_COLOR}/n): ")" explain_disk_opt
                if [[ "$explain_disk_opt" =~ ^[Yy]$ ]]; then
                    local disk_info; disk_info=$(du -sh "$specific_path"/* 2>/dev/null | sort -rh | head -n 20)
                    local prompt="Anda adalah AI asisten sistem Linux. Pengguna meminta saran optimasi ruang disk untuk path '${specific_path}'. Berikut adalah detail penggunaan disk di dalamnya:\n${disk_info}\n\nBerikan saran umum dan aman tentang bagaimana pengguna bisa mengoptimalkan atau membersihkan ruang disk di path ini. Fokus pada identifikasi jenis file yang biasanya aman untuk dihapus (seperti cache aplikasi, log lama, file unduhan yang tidak terpakai) atau yang mungkin bisa diarsip. Ingatkan pengguna untuk selalu berhati-hati dan mem-backup data penting sebelum menghapus. Format dalam Markdown."
                    ask_ai_gemini "$prompt"
                fi
            fi
        else echo -e "  ${ERROR_PREFIX} Direktori tidak ditemukan: $specific_path"; fi
    fi
    press_enter_to_continue
}

review_system_logs() {
    echo; echo -e "  ${INFO_PREFIX} Meninjau log sistem penting..."
    local log_file; local num_lines=30 # Perbanyak baris untuk konteks AI
    PS3="$(echo -e "  ${QUESTION_PREFIX}Pilih log (atau 0 untuk kembali): ${DEFAULT_COLOR}")"
    options=("/var/log/syslog" "/var/log/auth.log" "/var/log/kern.log" "/var/log/dpkg.log" "Path Kustom" "Kembali")
    echo; COLUMNS=1 
    select opt in "${options[@]}"; do
        case $opt in
            "/var/log/syslog") log_file="/var/log/syslog"; break;; "/var/log/auth.log") log_file="/var/log/auth.log"; break;;
            "/var/log/kern.log") log_file="/var/log/kern.log"; break;; "/var/log/dpkg.log") log_file="/var/log/dpkg.log"; break;;
            "Path Kustom")
                read -p "$(echo -e "  ${QUESTION_PREFIX}Masukkan path lengkap: ${DEFAULT_COLOR}")" custom_log_file
                if [ -f "$custom_log_file" ]; then log_file="$custom_log_file"; else echo -e "  ${ERROR_PREFIX} File tidak ditemukan."; log_file=""; fi; break;;
            "Kembali") clear; return;;
            *) echo -e "  ${ERROR_PREFIX} Pilihan tidak valid $REPLY";;
        esac
    done </dev/tty
    if [ -n "$log_file" ] && [ -f "$log_file" ]; then
        read -p "$(echo -e "  ${QUESTION_PREFIX}Baris terakhir (default: $num_lines)? ${DEFAULT_COLOR}")" lines_input
        if [[ "$lines_input" =~ ^[0-9]+$ ]] && [ "$lines_input" -gt 0 ]; then num_lines="$lines_input"; fi
        echo -e "  ${CYAN}Menampilkan ${num_lines} baris terakhir dari ${log_file}:${DEFAULT_COLOR}"
        tail -n "$num_lines" "$log_file" | sed 's/^/    /'; echo
        if [ "$AI_DEPENDENCIES_MET" -eq 1 ]; then
            read -p "$(echo -e "  ${QUESTION_PREFIX} Analisis AI untuk log ini? (${BOLD_GREEN}Y${DEFAULT_COLOR}/n): ")" explain_log_ai
            if [[ "$explain_log_ai" =~ ^[Yy]$ ]]; then
                local log_snippet; log_snippet=$(tail -n "$num_lines" "$log_file")
                local prompt="Anda adalah AI analis log sistem Linux. Analisis potongan log berikut dari file '${log_file}'. Fokus pada identifikasi dan penjelasan singkat mengenai: \n1. Error yang jelas (misalnya, 'failed', 'error', 'denied').\n2. Warning signifikan yang mungkin memerlukan perhatian.\n3. Pola atau anomali yang mencurigakan (misalnya, percobaan login berulang, aktivitas tidak biasa).\n4. Jika ada, berikan saran tindakan atau investigasi lebih lanjut yang mungkin relevan.\n\nPotongan log:\n\`\`\`\n${log_snippet}\n\`\`\`\nFormat respons dalam Markdown yang terstruktur."
                ask_ai_gemini "$prompt"
            fi
        fi
    elif [ -n "$log_file" ]; then echo -e "  ${ERROR_PREFIX} Tidak dapat menampilkan log: $log_file"; fi
    press_enter_to_continue
}

# Fungsi untuk menjalankan semua tugas pembersihan
run_all_cleanup() {
    clear; show_ascii_art; echo
    echo -e "  ${INFO_PREFIX} Menjalankan SEMUA tugas pembersihan utama..."
    echo -e "  ${WARNING_PREFIX} Beberapa tindakan destruktif & perlu konfirmasi individual (termasuk opsi AI)."
    read -p "$(echo -e "  ${QUESTION_PREFIX} Yakin ingin melanjutkan? (${BOLD_GREEN}yes${DEFAULT_COLOR}/${BOLD_RED}NO${DEFAULT_COLOR}): ")" confirm_all
    if [[ "$confirm_all" == "yes" ]]; then
        # Daftar fungsi pembersihan utama yang akan dijalankan
        # Tidak termasuk pembersihan cache aplikasi individual karena itu ada di submenu
        # dan biasanya lebih spesifik kebutuhan pengguna.
        local main_cleanup_funcs=(
            clean_apt
            clean_var_log
            configure_clean_journald 
            clean_tmp_files
            clean_user_cache
            clean_docker # Docker cleanup adalah operasi besar, jadi dimasukkan
        )
        for func_name in "${main_cleanup_funcs[@]}"; do
            clear; show_ascii_art
            echo -e "  ${BOLD_CYAN}>>> Menjalankan: ${func_name//_/ } <<<${DEFAULT_COLOR}"
            # Panggil fungsi
            if declare -f "$func_name" > /dev/null; then
                "$func_name" # Ini akan memanggil press_enter_to_continue di dalamnya
            else
                echo -e "  ${ERROR_PREFIX} Fungsi ${func_name} tidak ditemukan."
                press_enter_to_continue
            fi
        done
        echo -e "  ${SUCCESS_PREFIX} SEMUA tugas pembersihan utama telah dijalankan (sesuai konfirmasi individual)."
    else
        echo -e "  ${SKIPPED_PREFIX} Operasi 'Jalankan Semua' dibatalkan."
    fi
    press_enter_to_continue
}

# --- Menu Utama ---
show_main_menu() {
    clear; show_ascii_art
    echo -e "  ╭───────────────────────────────────────────────────────────╮"
    echo -e "  │ ${BOLD_WHITE}Pilih opsi pembersihan atau utilitas:${DEFAULT_COLOR}                     │"
    echo -e "  ├───────────────────────────────────────────────────────────┤"
    echo -e "  │ ${BOLD_YELLOW}Pembersihan Sistem Umum:${DEFAULT_COLOR}                                  │"
    echo -e "  │   ${BOLD_YELLOW}1.${DEFAULT_COLOR} Bersihkan Cache Apt-get                               │"
    echo -e "  │   ${BOLD_YELLOW}2.${DEFAULT_COLOR} Hapus Paket Tertentu ${CYAN}(AI Info)${DEFAULT_COLOR}                       │"
    echo -e "  │   ${BOLD_YELLOW}3.${DEFAULT_COLOR} Bersihkan Log Lama (/var/log) ${CYAN}(AI Explain)${DEFAULT_COLOR}           │"
    echo -e "  │   ${BOLD_YELLOW}4.${DEFAULT_COLOR} Konfigurasi & Bersihkan Journald ${CYAN}(AI Explain)${DEFAULT_COLOR}       │"
    echo -e "  │   ${BOLD_YELLOW}5.${DEFAULT_COLOR} Hapus File Sementara (/tmp) ${CYAN}(AI Explain)${DEFAULT_COLOR}              │"
    echo -e "  │   ${BOLD_YELLOW}6.${DEFAULT_COLOR} Bersihkan Cache Pengguna (~/.cache) ${CYAN}(AI Explain)${DEFAULT_COLOR}      │"
    echo -e "  │ ${BOLD_YELLOW}Pembersihan Cache Aplikasi:${DEFAULT_COLOR}                               │"
    echo -e "  │   ${BOLD_YELLOW}7.${DEFAULT_COLOR} Pembersihan Cache Aplikasi (NPM, Pip, Go, dll.)       │"
    echo -e "  │ ${BOLD_YELLOW}Pembersihan Docker:${DEFAULT_COLOR}                                       │"
    echo -e "  │   ${BOLD_YELLOW}8.${DEFAULT_COLOR} Pembersihan Docker Lengkap ${CYAN}(AI Explain)${DEFAULT_COLOR}              │"
    echo -e "  │ ${BOLD_YELLOW}Utilitas Sistem:${DEFAULT_COLOR}                                          │"
    echo -e "  │   ${BOLD_YELLOW}9.${DEFAULT_COLOR} Utilitas (Analisis Disk ${CYAN}(AI Suggest)${DEFAULT_COLOR}, Tinjau Log ${CYAN}(AI Analyze)${DEFAULT_COLOR})│"
    echo -e "  ├───────────────────────────────────────────────────────────┤"
    echo -e "  │ ${BOLD_GREEN}13. JALANKAN SEMUA Pembersihan Utama${DEFAULT_COLOR}                       │"
    echo -e "  │ ${BOLD_RED} 0. Keluar${DEFAULT_COLOR}                                                   │"
    echo -e "  ╰───────────────────────────────────────────────────────────╯"
}

# Loop utama untuk menu
while true; do
    show_main_menu
    read -p "$(echo -e "  ${BOLD_WHITE}Masukkan pilihan Anda [0-9, 13]: ${DEFAULT_COLOR}")" choice
    case $choice in
        1) clear; clean_apt ;; 2) clear; remove_specific_packages ;;
        3) clear; clean_var_log ;; 4) clear; configure_clean_journald ;;
        5) clear; clean_tmp_files ;; 6) clear; clean_user_cache ;;
        7) submenu_app_cache_cleanup ;; 8) clear; clean_docker ;;
        9) submenu_system_utilities ;; 13) run_all_cleanup ;; 
        0) echo -e "  ${BOLD_GREEN}Keluar dari skrip. Sampai jumpa!${DEFAULT_COLOR}"; break ;;
        *) echo -e "  ${ERROR_PREFIX} Pilihan tidak valid." ; sleep 2 ;;
    esac
done

echo; echo -e "  ${BOLD_MAGENTA}=======================================${DEFAULT_COLOR}"
echo -e "  ${BOLD_GREEN}Skrip Pembersihan Server Linux Selesai.${DEFAULT_COLOR}"
echo -e "  ${YELLOW}Tinjau output untuk error atau langkah yang dilewati.${DEFAULT_COLOR}"; echo
