#!/usr/bin/env bash
# PRA CLEAN Utility (refactor)
# Kompatibel: Ubuntu/Debian dengan systemd
# Refactor dari skrip pengguna (perbaikan efisiensi & keamanan)

set -Eeuo pipefail

# ========== Warna (otomatis nonaktif bila non-TTY) ==========
if [ -t 1 ]; then
  DEFAULT_COLOR='\e[0m'; BLACK='\e[0;30m'; RED='\e[0;31m'; GREEN='\e[0;32m'; YELLOW='\e[0;33m'
  BLUE='\e[0;34m'; MAGENTA='\e[0;35m'; CYAN='\e[0;36m'; WHITE='\e[0;37m'
  BOLD_BLACK='\e[1;30m'; BOLD_RED='\e[1;31m'; BOLD_GREEN='\e[1;32m'; BOLD_YELLOW='\e[1;33m'
  BOLD_BLUE='\e[1;34m'; BOLD_MAGENTA='\e[1;35m'; BOLD_CYAN='\e[1;36m'; BOLD_WHITE='\e[1;37m'
else
  DEFAULT_COLOR=''; BLACK=''; RED=''; GREEN=''; YELLOW=''; BLUE=''; MAGENTA=''; CYAN=''; WHITE=''
  BOLD_BLACK=''; BOLD_RED=''; BOLD_GREEN=''; BOLD_YELLOW=''; BOLD_BLUE=''; BOLD_MAGENTA=''; BOLD_CYAN=''; BOLD_WHITE=''
fi

INFO_PREFIX="${BOLD_BLUE}[INFO]${DEFAULT_COLOR}"
WARNING_PREFIX="${BOLD_YELLOW}[PERINGATAN]${DEFAULT_COLOR}"
ERROR_PREFIX="${BOLD_RED}[ERROR]${DEFAULT_COLOR}"
SUCCESS_PREFIX="${BOLD_GREEN}[BERHASIL]${DEFAULT_COLOR}"
SKIPPED_PREFIX="${YELLOW}[DILEWATI]${DEFAULT_COLOR}"
QUESTION_PREFIX="${BOLD_CYAN}[PERTANYAAN]${DEFAULT_COLOR}"
AI_PREFIX="${BOLD_MAGENTA}[AI GEMINI]${DEFAULT_COLOR}"

# ========== AI (opsional) ==========
GEMINI_API_KEY="${PRA_CLEAN_GEMINI_API_KEY:-${GEMINI_API_KEY:-}}"
GEMINI_API_ENDPOINT="https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash-latest:generateContent"
AI_DEPENDENCIES_MET=0
GLOW_INSTALLED=0

# ========== Util umum ==========
cleanup_cursor() { command -v tput >/dev/null 2>&1 && tput cnorm || true; }
trap cleanup_cursor EXIT INT TERM

has_cmd() { command -v "$1" >/dev/null 2>&1; }

confirm() {
  # usage: confirm "pesan" ; return 0 jika yes
  local ans
  read -r -p "$(echo -e "  ${QUESTION_PREFIX} $1 (${BOLD_GREEN}yes${DEFAULT_COLOR}/${BOLD_RED}NO${DEFAULT_COLOR}): ")" ans || true
  [[ "${ans:-}" == "yes" ]]
}

press_enter() {
  read -n 1 -s -r -p "$(echo -e "  ${YELLOW}Tekan Enter untuk kembali...${DEFAULT_COLOR}")" || true
  echo
}

run_as_user() {
  # usage: run_as_user <user> <cmd...>
  local u="$1"; shift
  if [ "$u" = "root" ] || [ -z "$u" ]; then
    "$@"
  else
    sudo -u "$u" -- "$@"
  fi
}

is_valid_size() { [[ "$1" =~ ^[0-9]+[KMG]?$ ]]; }
is_valid_time() { [[ "$1" =~ ^[0-9]+[smhdw]$ ]]; }

# ========== Loading kecil ==========
show_loading_animation() {
  command -v tput >/dev/null 2>&1 && tput civis || true
  local spin='|/-\' i=0 t_end=$((SECONDS+1))
  while (( SECONDS < t_end )); do
    printf "  ${BOLD_CYAN}Memuat PRA CLEAN Utility %c ${DEFAULT_COLOR}\r" "${spin:i++%4:1}"
    sleep 0.1
  done
  printf "                                        \r"
  cleanup_cursor
  echo
}

# ========== AI helpers ==========
check_ai_dependencies() {
  local ok=1
  has_cmd curl || { echo -e "  ${YELLOW}Fitur AI butuh 'curl'.${DEFAULT_COLOR}"; ok=0; }
  has_cmd jq   || { echo -e "  ${YELLOW}Fitur AI butuh 'jq'.${DEFAULT_COLOR}"; ok=0; }
  AI_DEPENDENCIES_MET=$ok
  has_cmd glow && GLOW_INSTALLED=1 || GLOW_INSTALLED=0
  if (( ! AI_DEPENDENCIES_MET )); then
    echo -e "  ${WARNING_PREFIX} Dependensi AI belum lengkap. Fitur AI akan dilewati."
  fi
}

ask_ai_gemini() {
  local prompt_text="$1"
  (( AI_DEPENDENCIES_MET )) || { echo -e "  ${SKIPPED_PREFIX} AI dilewati (dependensi)."; return 1; }
  [ -n "${GEMINI_API_KEY:-}" ] || { echo -e "  ${SKIPPED_PREFIX} AI dilewati (API key kosong)."; return 1; }

  echo -e "  ${INFO_PREFIX} Menghubungi AI Gemini..."
  command -v tput >/dev/null 2>&1 && tput civis || true

  local payload response
  payload=$(jq -n --arg prompt "$prompt_text" '{contents:[{parts:[{text:$prompt}]}],"generationConfig":{"temperature":0.5,"maxOutputTokens":2048}}')
  response=$(curl -s -X POST "${GEMINI_API_ENDPOINT}?key=${GEMINI_API_KEY}" -H "Content-Type: application/json" -d "$payload" || true)

  cleanup_cursor

  local err msg
  err=$(echo "$response" | jq -r '.error.message // empty' 2>/dev/null || true)
  if [ -n "$err" ]; then
    echo -e "  ${ERROR_PREFIX} API Gemini: $err"; return 1
  fi
  msg=$(echo "$response" | jq -r '.candidates[0].content.parts[0].text // empty' 2>/dev/null || true)
  if [ -z "$msg" ]; then
    echo -e "  ${WARNING_PREFIX} Respons AI kosong."; return 1
  fi

  echo -e "\n  ${AI_PREFIX} Respons AI:"
  echo -e "${CYAN}---------------------------------------------------------------------${DEFAULT_COLOR}"
  if (( GLOW_INSTALLED )); then
    echo -e "$msg" | glow -s dark -w "$(( $(tput cols 2>/dev/null || echo 120) - 8 ))"
  else
    echo -e "$msg" | sed 's/^/    /'
  fi
  echo -e "${CYAN}---------------------------------------------------------------------${DEFAULT_COLOR}"
}

# ========== Root check ==========
check_sudo() {
  if [[ "${EUID}" -ne 0 ]]; then
    echo -e "${WARNING_PREFIX} Skrip ini memerlukan hak akses root."
    echo -e "${INFO_PREFIX} Jalankan: sudo $0"
    exit 1
  fi
}

# ========== Header ==========
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
  echo -e "${BOLD_MAGENTA}                        PRA CLEAN UTILITY (Refactor)                   ${DEFAULT_COLOR}"
  echo -e "${BOLD_MAGENTA}=======================================================================${DEFAULT_COLOR}"
  echo -e "${CYAN}                        Developed by: jayyidsptr                       ${DEFAULT_COLOR}"
  echo -e "${CYAN}                 https://github.com/jayyidsptr                          ${DEFAULT_COLOR}"
  [ -n "${GEMINI_API_KEY:-}" ] && echo -e "${BLUE}                 ✨ Fitur AI Gemini Aktif ✨${DEFAULT_COLOR}"
  echo
}

# ========== Aksi pembersihan ==========
clean_apt() {
  echo; echo -e "  ${INFO_PREFIX} Membersihkan cache apt-get..."
  apt-get -y autoclean
  apt-get -y clean
  echo -e "  ${INFO_PREFIX} Menghapus paket tak terpakai (autoremove)..."
  apt-get -y autoremove
  echo -e "  ${SUCCESS_PREFIX} Pembersihan apt-get selesai."
  press_enter
}

remove_specific_packages() {
  echo; read -r -p "$(echo -e "  ${QUESTION_PREFIX} Nama paket (pisahkan spasi, kosongkan untuk batal): ")" pkgs || true
  [ -n "${pkgs:-}" ] || { echo -e "  ${SKIPPED_PREFIX} Tidak ada paket yang ditentukan."; press_enter; return; }

  if [ -n "${GEMINI_API_KEY:-}" ] && (( AI_DEPENDENCIES_MET )); then
    read -r -p "$(echo -e "  ${QUESTION_PREFIX} Tampilkan info AI dampak hapus paket tsb? (${BOLD_GREEN}y${DEFAULT_COLOR}/N): ")" e || true
    [[ "${e:-}" =~ ^[Yy]$ ]] && ask_ai_gemini "Jelaskan fungsi dan risiko menghapus paket: $pkgs (Ubuntu Server)."
  fi

  if confirm "YAKIN hapus '${BOLD_RED}${pkgs}${DEFAULT_COLOR}'"; then
    # shellcheck disable=SC2086
    apt-get -y remove $pkgs
    echo -e "  ${SUCCESS_PREFIX} Penghapusan paket selesai."
  else
    echo -e "  ${SKIPPED_PREFIX} Dibatalkan."
  fi
  press_enter
}

clean_var_log() {
  echo; echo -e "  ${INFO_PREFIX} Membersihkan log di /var/log (AMAN)..."
  echo -e "  ${CYAN}- Truncate file log biasa, hapus arsip lama (*.gz, *.1, *.old)${DEFAULT_COLOR}"
  echo -e "  ${CYAN}- Tidak menghapus direktori log aktif${DEFAULT_COLOR}"

  if confirm "Lanjutkan pembersihan /var/log secara aman"; then
    # Truncate file log (kecuali wtmp/btmp/lastlog) & hapus arsip lama
    find /var/log -type f \
      ! -name 'wtmp' ! -name 'btmp' ! -name 'lastlog' \
      -exec sh -c 'case "$1" in *.gz|*.xz|*.zst|*.1|*.old) rm -f "$1";; *) : > "$1";; esac' _ {} \;

    echo -e "  ${SUCCESS_PREFIX} /var/log dibersihkan secara aman."
  else
    echo -e "  ${SKIPPED_PREFIX} Pembersihan /var/log dilewati."
  fi
  press_enter
}

configure_clean_journald() {
  echo; echo -e "  ${INFO_PREFIX} Konfigurasi & pembersihan systemd-journald..."
  local conf=/etc/systemd/journald.conf
  local cur_use cur_file
  cur_use=$(grep -Po '^SystemMaxUse=\K.*' "$conf" 2>/dev/null || echo "Tidak diatur")
  cur_file=$(grep -Po '^SystemMaxFileSize=\K.*' "$conf" 2>/dev/null || echo "Tidak diatur")
  echo -e "  ${CYAN}Konfigurasi saat ini: SystemMaxUse=${BOLD_YELLOW}${cur_use}${DEFAULT_COLOR}, SystemMaxFileSize=${BOLD_YELLOW}${cur_file}${DEFAULT_COLOR}"

  read -r -p "$(echo -e "  ${QUESTION_PREFIX} Ubah batasan ukuran? (${BOLD_GREEN}y${DEFAULT_COLOR}/N): ")" change || true
  if [[ "${change:-}" =~ ^[Yy]$ ]]; then
    read -r -p "$(echo -e "  ${QUESTION_PREFIX} SystemMaxUse (mis: 1G, kosong=skip): ")" max_use || true
    read -r -p "$(echo -e "  ${QUESTION_PREFIX} SystemMaxFileSize (mis: 50M, kosong=skip): ")" max_file || true

    if [ -f "$conf" ]; then
      if [ -n "${max_use:-}" ] && is_valid_size "$max_use"; then
        grep -q '^SystemMaxUse=' "$conf" && sed -i "s/^SystemMaxUse=.*/SystemMaxUse=$max_use/" "$conf" || sed -i '/\[Journal\]/a SystemMaxUse='"$max_use" "$conf"
        echo -e "  ${INFO_PREFIX} SystemMaxUse -> $max_use"
      fi
      if [ -n "${max_file:-}" ] && is_valid_size "$max_file"; then
        grep -q '^SystemMaxFileSize=' "$conf" && sed -i "s/^SystemMaxFileSize=.*/SystemMaxFileSize=$max_file/" "$conf" || sed -i '/\[Journal\]/a SystemMaxFileSize='"$max_file" "$conf"
        echo -e "  ${INFO_PREFIX} SystemMaxFileSize -> $max_file"
      fi
      systemctl restart systemd-journald || true
    else
      echo -e "  ${WARNING_PREFIX} $conf tidak ditemukan."
    fi
  fi

  read -r -p "$(echo -e "  ${QUESTION_PREFIX} Vacuum berdasarkan waktu (mis: 2d, kosong=skip): ")" vtime || true
  [ -n "${vtime:-}" ] && is_valid_time "$vtime" && journalctl --vacuum-time="$vtime" || true

  read -r -p "$(echo -e "  ${QUESTION_PREFIX} Vacuum berdasarkan ukuran (mis: 200M, kosong=skip): ")" vsize || true
  [ -n "${vsize:-}" ] && is_valid_size "$vsize" && journalctl --vacuum-size="$vsize" || true

  echo -e "  ${SUCCESS_PREFIX} Selesai konfigurasi & pembersihan journald."
  press_enter
}

clean_tmp_files() {
  echo; echo -e "  ${INFO_PREFIX} Membersihkan /tmp (hapus isi, bukan direktori)..."
  echo -e "  ${WARNING_PREFIX} Pastikan tidak ada aplikasi aktif yang memakai /tmp."
  if confirm "Hapus semua isi /tmp"; then
    find /tmp -mindepth 1 -maxdepth 1 -exec rm -rf -- {} +
    echo -e "  ${SUCCESS_PREFIX} /tmp dibersihkan."
  else
    echo -e "  ${SKIPPED_PREFIX} Pembersihan /tmp dilewati."
  fi
  press_enter
}

clean_user_cache() {
  echo
  local target_user="${SUDO_USER:-root}"
  local user_home
  user_home=$(getent passwd "$target_user" | cut -d: -f6 || true)
  local user_cache_dir="${user_home:-/root}/.cache"

  if [ ! -d "$user_cache_dir" ]; then
    echo -e "  ${WARNING_PREFIX} Direktori cache tidak ditemukan untuk $target_user ($user_cache_dir)."
    press_enter; return
  fi

  echo -e "  ${INFO_PREFIX} Membersihkan cache user: ${BOLD_YELLOW}${user_cache_dir}${DEFAULT_COLOR}"
  echo -e "  ${CYAN}10 item terbesar:${DEFAULT_COLOR}"
  run_as_user "$target_user" du -sh "$user_cache_dir"/* 2>/dev/null | sort -hr | head -n 10

  if confirm "Lanjutkan hapus semua isi di ${user_cache_dir}?"; then
    run_as_user "$target_user" find "$user_cache_dir" -mindepth 1 -delete
    echo -e "  ${SUCCESS_PREFIX} Cache pengguna dibersihkan."
  else
    echo -e "  ${SKIPPED_PREFIX} Pembersihan cache user dilewati."
  fi
  press_enter
}

# ---- Submenu cache aplikasi ----
clean_npm_cache() {
  echo; echo -e "  ${INFO_PREFIX} Membersihkan cache NPM..."
  if has_cmd npm; then
    local u="${SUDO_USER:-root}"
    run_as_user "$u" npm cache clean --force
    run_as_user "$u" npm cache verify || true
    echo -e "  ${SUCCESS_PREFIX} Cache NPM dibersihkan."
  else
    echo -e "  ${SKIPPED_PREFIX} npm tidak ditemukan."
  fi
  press_enter
}

clean_pip3_cache() {
  echo; echo -e "  ${INFO_PREFIX} Membersihkan cache Pip3..."
  if has_cmd pip3; then
    local u="${SUDO_USER:-root}"
    echo -e "  ${CYAN}Info cache:${DEFAULT_COLOR}"
    run_as_user "$u" pip3 cache info || true
    run_as_user "$u" pip3 cache purge || true
    echo -e "  ${SUCCESS_PREFIX} Cache Pip3 dibersihkan."
  else
    echo -e "  ${SKIPPED_PREFIX} pip3 tidak ditemukan."
  fi
  press_enter
}

clean_go_cache() {
  echo; echo -e "  ${INFO_PREFIX} Membersihkan cache Go..."
  if has_cmd go; then
    local u="${SUDO_USER:-root}"
    local GOCACHE_DIR; GOCACHE_DIR=$(run_as_user "$u" go env GOCACHE 2>/dev/null || echo "")
    if [ -n "$GOCACHE_DIR" ] && [ -d "$GOCACHE_DIR" ]; then
      echo -e "  ${CYAN}Ukuran cache ($GOCACHE_DIR):${DEFAULT_COLOR}"
      run_as_user "$u" du -sh "$GOCACHE_DIR" || true
      run_as_user "$u" go clean -cache
      run_as_user "$u" go clean -modcache
      echo -e "  ${SUCCESS_PREFIX} Cache Go dibersihkan."
    else
      echo -e "  ${SKIPPED_PREFIX} Cache Go tidak ditemukan."
    fi
  else
    echo -e "  ${SKIPPED_PREFIX} go tidak ditemukan."
  fi
  press_enter
}

clean_maven_cache() {
  echo; echo -e "  ${INFO_PREFIX} Membersihkan cache Maven..."
  local u="${SUDO_USER:-root}"
  local repo="$(getent passwd "$u" | cut -d: -f6)/.m2/repository"
  if [ -d "$repo" ]; then
    echo -e "  ${WARNING_PREFIX} Ini akan menghapus repositori Maven: ${BOLD_YELLOW}$repo${DEFAULT_COLOR}"
    if confirm "Lanjutkan"; then
      run_as_user "$u" rm -rf "$repo"
      echo -e "  ${SUCCESS_PREFIX} Cache Maven dibersihkan."
    else
      echo -e "  ${SKIPPED_PREFIX} Dilewati."
    fi
  else
    echo -e "  ${SKIPPED_PREFIX} $repo tidak ditemukan."
  fi
  press_enter
}

clean_gradle_cache() {
  echo; echo -e "  ${INFO_PREFIX} Membersihkan cache Gradle..."
  local u="${SUDO_USER:-root}"
  local caches="$(getent passwd "$u" | cut -d: -f6)/.gradle/caches"
  if [ -d "$caches" ]; then
    has_cmd gradle && { echo -e "  ${INFO_PREFIX} Menghentikan daemon Gradle..."; run_as_user "$u" gradle --stop >/dev/null 2>&1 || true; }
    echo -e "  ${WARNING_PREFIX} Ini akan menghapus cache Gradle: ${BOLD_YELLOW}$caches${DEFAULT_COLOR}"
    if confirm "Lanjutkan"; then
      run_as_user "$u" rm -rf "$caches"
      echo -e "  ${SUCCESS_PREFIX} Cache Gradle dibersihkan."
    else
      echo -e "  ${SKIPPED_PREFIX} Dilewati."
    fi
  else
    echo -e "  ${SKIPPED_PREFIX} $caches tidak ditemukan."
  fi
  press_enter
}

# ---- Docker ----
clean_docker() {
  echo; echo -e "  ${INFO_PREFIX} Pembersihan Docker..."
  if ! has_cmd docker; then
    echo -e "  ${SKIPPED_PREFIX} docker tidak ditemukan."
    press_enter; return
  fi

  [ -d /var/lib/docker ] && { echo -e "  ${CYAN}Ukuran /var/lib/docker:${DEFAULT_COLOR}"; du -sh /var/lib/docker 2>/dev/null || true; echo; }

  echo -e "  ${INFO_PREFIX} Image dangling prune..."
  docker image prune -f || true; echo

  if confirm "Pangkas SEMUA image tak terpakai (image prune -a)"; then
    docker image prune -a -f || true
  else
    echo -e "  ${SKIPPED_PREFIX} image prune -a dilewati."
  fi
  echo

  echo -e "  ${INFO_PREFIX} Volume prune..."
  docker volume prune -f || true; echo

  echo -e "  ${INFO_PREFIX} System prune..."
  docker system prune -f || true; echo

  if confirm "Lanjut system prune -a (hapus kontainer berhenti & semua image tak terpakai)"; then
    docker system prune -a -f || true
  else
    echo -e "  ${SKIPPED_PREFIX} system prune -a dilewati."
  fi
  echo

  echo -e "  ${INFO_PREFIX} Builder cache prune..."
  docker builder prune -f || true; echo
  if confirm "Pangkas SEMUA builder cache (builder prune -a)"; then
    docker builder prune -a -f || true
  else
    echo -e "  ${SKIPPED_PREFIX} builder prune -a dilewati."
  fi

  echo -e "  ${SUCCESS_PREFIX} Pembersihan Docker selesai."
  press_enter
}

# ---- Utilitas sistem ----
analyze_disk_usage() {
  echo; echo -e "  ${INFO_PREFIX} Analisis penggunaan disk ringkas..."
  echo -e "  ${CYAN}Penggunaan filesystem:${DEFAULT_COLOR}"
  df -h | sed 's/^/    /'
  echo
  echo -e "  ${CYAN}Top direktori di root (kedalaman 1):${DEFAULT_COLOR}"
  du -xh --max-depth=1 / 2>/dev/null | sort -rh | head -n 15 | sed 's/^/    /'
  echo
  read -r -p "$(echo -e "  ${QUESTION_PREFIX} Path spesifik (kosong=skip): ")" p || true
  if [ -n "${p:-}" ] && [ -d "$p" ]; then
    echo -e "  ${CYAN}Top item di ${p}:${DEFAULT_COLOR}"
    du -xh --max-depth=1 "$p" 2>/dev/null | sort -rh | head -n 20 | sed 's/^/    /'
    if [ -n "${GEMINI_API_KEY:-}" ] && (( AI_DEPENDENCIES_MET )); then
      read -r -p "$(echo -e "  ${QUESTION_PREFIX} Saran optimasi AI untuk path ini? (${BOLD_GREEN}y${DEFAULT_COLOR}/N): ")" a || true
      [[ "${a:-}" =~ ^[Yy]$ ]] && ask_ai_gemini "Berikan saran aman mengosongkan ruang di: $p. Tunjukkan tipe file umum yang aman dihapus (cache/log lama/unduhan) dan yang sebaiknya diarsip."
    fi
  fi
  press_enter
}

review_system_logs() {
  echo; echo -e "  ${INFO_PREFIX} Tinjau log sistem..."
  local options=("/var/log/syslog" "/var/log/auth.log" "/var/log/kern.log" "/var/log/dpkg.log" "Path Kustom" "Kembali")
  local PS3="$(echo -e "  ${QUESTION_PREFIX} Pilih log (0 untuk kembali): ${DEFAULT_COLOR}")"
  COLUMNS=1
  select opt in "${options[@]}"; do
    local log_file=""; local lines=30
    case "$opt" in
      "/var/log/syslog"|"/var/log/auth.log"|"/var/log/kern.log"|"/var/log/dpkg.log") log_file="$opt";;
      "Path Kustom") read -r -p "$(echo -e "  ${QUESTION_PREFIX} Path lengkap: ${DEFAULT_COLOR}")" log_file || true;;
      "Kembali") return;;
      *) echo -e "  ${ERROR_PREFIX} Pilihan tidak valid."; continue;;
    esac

    if [ -n "$log_file" ] && [ -f "$log_file" ]; then
      read -r -p "$(echo -e "  ${QUESTION_PREFIX} Baris terakhir (default: $lines): ${DEFAULT_COLOR}")" l || true
      [[ "${l:-}" =~ ^[0-9]+$ ]] && lines="$l"
      echo -e "  ${CYAN}Tail ${lines} baris dari ${log_file}:${DEFAULT_COLOR}"
      tail -n "$lines" "$log_file" | sed 's/^/    /'
      echo
      if [ -n "${GEMINI_API_KEY:-}" ] && (( AI_DEPENDENCIES_MET )); then
        read -r -p "$(echo -e "  ${QUESTION_PREFIX} Analisis AI untuk log ini? (${BOLD_GREEN}y${DEFAULT_COLOR}/N): ")" al || true
        if [[ "${al:-}" =~ ^[Yy]$ ]]; then
          local snippet; snippet=$(tail -n "$lines" "$log_file")
          ask_ai_gemini "Analisis potongan log berikut (error, warning, pola aneh) dan beri saran singkat:\n\`\`\`\n${snippet}\n\`\`\`"
        fi
      fi
    else
      echo -e "  ${ERROR_PREFIX} File tidak ditemukan: $log_file"
    fi
    press_enter; break
  done </dev/tty
}

submenu_app_cache_cleanup() {
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
    echo -e "  │ ${BOLD_YELLOW}0.${DEFAULT_COLOR} ${BOLD_RED}Kembali${DEFAULT_COLOR}                                   │"
    echo -e "  ╰────────────────────────────────────────────────────╯"
    read -r -p "$(echo -e "  ${BOLD_WHITE}Pilihan [0-5]: ${DEFAULT_COLOR}")" c || true
    case "${c:-}" in
      1) clear; clean_npm_cache ;;
      2) clear; clean_pip3_cache ;;
      3) clear; clean_go_cache ;;
      4) clear; clean_maven_cache ;;
      5) clear; clean_gradle_cache ;;
      0) break ;;
      *) echo -e "  ${ERROR_PREFIX} Pilihan tidak valid."; sleep 1 ;;
    esac
  done
}

submenu_system_utilities() {
  while true; do
    clear; show_ascii_art
    echo -e "  ╭────────────────────────────────────────────────────╮"
    echo -e "  │ ${BOLD_WHITE}Utilitas Sistem${DEFAULT_COLOR}                                  │"
    echo -e "  ├────────────────────────────────────────────────────┤"
    echo -e "  │ ${BOLD_YELLOW}1.${DEFAULT_COLOR} Analisis Penggunaan Disk ${CYAN}(AI Ready)${DEFAULT_COLOR}             │"
    echo -e "  │ ${BOLD_YELLOW}2.${DEFAULT_COLOR} Tinjau Log Sistem Penting ${CYAN}(AI Ready)${DEFAULT_COLOR}          │"
    echo -e "  │ ${BOLD_YELLOW}0.${DEFAULT_COLOR} ${BOLD_RED}Kembali${DEFAULT_COLOR}                                   │"
    echo -e "  ╰────────────────────────────────────────────────────╯"
    read -r -p "$(echo -e "  ${BOLD_WHITE}Pilihan [0-2]: ${DEFAULT_COLOR}")" u || true
    case "${u:-}" in
      1) clear; analyze_disk_usage ;;
      2) clear; review_system_logs ;;
      0) break ;;
      *) echo -e "  ${ERROR_PREFIX} Pilihan tidak valid."; sleep 1 ;;
    esac
  done
}

run_all_cleanup() {
  clear; show_ascii_art; echo
  echo -e "  ${INFO_PREFIX} Menjalankan SEMUA pembersihan utama..."
  echo -e "  ${WARNING_PREFIX} Tindakan akan meminta konfirmasi di tiap langkah."
  if confirm "Lanjutkan"; then
    local steps=(clean_apt clean_var_log configure_clean_journald clean_tmp_files clean_user_cache clean_docker)
    for s in "${steps[@]}"; do
      clear; show_ascii_art
      echo -e "  ${BOLD_CYAN}>>> Menjalankan: ${s//_/ } <<<${DEFAULT_COLOR}"
      "$s"
    done
    echo -e "  ${SUCCESS_PREFIX} Semua pembersihan utama selesai."
  else
    echo -e "  ${SKIPPED_PREFIX} Operasi dibatalkan."
  fi
  press_enter
}

# ========== Main ==========
check_sudo
show_loading_animation
check_ai_dependencies

show_main_menu() {
  clear; show_ascii_art
  echo -e "  ╭───────────────────────────────────────────────────────────╮"
  echo -e "  │ ${BOLD_WHITE}Pilih opsi pembersihan atau utilitas:${DEFAULT_COLOR}                     │"
  echo -e "  ├───────────────────────────────────────────────────────────┤"
  echo -e "  │ ${BOLD_YELLOW}Pembersihan Sistem Umum:${DEFAULT_COLOR}                                  │"
  echo -e "  │   ${BOLD_YELLOW}1.${DEFAULT_COLOR} Bersihkan Cache Apt-get                               │"
  echo -e "  │   ${BOLD_YELLOW}2.${DEFAULT_COLOR} Hapus Paket Tertentu ${CYAN}(AI Info)${DEFAULT_COLOR}                     │"
  echo -e "  │   ${BOLD_YELLOW}3.${DEFAULT_COLOR} Bersihkan Log (/var/log) Aman ${CYAN}(AI Explain)${DEFAULT_COLOR}         │"
  echo -e "  │   ${BOLD_YELLOW}4.${DEFAULT_COLOR} Konfigurasi & Bersihkan Journald ${CYAN}(AI Explain)${DEFAULT_COLOR}     │"
  echo -e "  │   ${BOLD_YELLOW}5.${DEFAULT_COLOR} Hapus File Sementara (/tmp) ${CYAN}(AI Explain)${DEFAULT_COLOR}          │"
  echo -e "  │   ${BOLD_YELLOW}6.${DEFAULT_COLOR} Bersihkan Cache Pengguna (~/.cache) ${CYAN}(AI Explain)${DEFAULT_COLOR}  │"
  echo -e "  │ ${BOLD_YELLOW}Pembersihan Cache Aplikasi:${DEFAULT_COLOR}                               │"
  echo -e "  │   ${BOLD_YELLOW}7.${DEFAULT_COLOR} NPM / Pip3 / Go / Maven / Gradle                      │"
  echo -e "  │ ${BOLD_YELLOW}Pembersihan Docker:${DEFAULT_COLOR}                                       │"
  echo -e "  │   ${BOLD_YELLOW}8.${DEFAULT_COLOR} Pembersihan Docker Lengkap ${CYAN}(AI Explain)${DEFAULT_COLOR}          │"
  echo -e "  │ ${BOLD_YELLOW}Utilitas Sistem:${DEFAULT_COLOR}                                          │"
  echo -e "  │   ${BOLD_YELLOW}9.${DEFAULT_COLOR} Analisis Disk & Tinjau Log ${CYAN}(AI)${DEFAULT_COLOR}                 │"
  echo -e "  ├───────────────────────────────────────────────────────────┤"
  echo -e "  │ ${BOLD_GREEN}13.${DEFAULT_COLOR} JALANKAN SEMUA Pembersihan Utama                       │"
  echo -e "  │ ${BOLD_RED} 0.${DEFAULT_COLOR} Keluar                                                   │"
  echo -e "  ╰───────────────────────────────────────────────────────────╯"
}

while true; do
  show_main_menu
  read -r -p "$(echo -e "  ${BOLD_WHITE}Masukkan pilihan [0-9,13]: ${DEFAULT_COLOR}")" choice || true
  case "${choice:-}" in
    1) clear; clean_apt ;;
    2) clear; remove_specific_packages ;;
    3) clear; clean_var_log ;;
    4) clear; configure_clean_journald ;;
    5) clear; clean_tmp_files ;;
    6) clear; clean_user_cache ;;
    7) submenu_app_cache_cleanup ;;
    8) clear; clean_docker ;;
    9) submenu_system_utilities ;;
    13) run_all_cleanup ;;
    0) echo -e "  ${BOLD_GREEN}Keluar. Sampai jumpa!${DEFAULT_COLOR}"; break ;;
    *) echo -e "  ${ERROR_PREFIX} Pilihan tidak valid."; sleep 1 ;;
  esac
done

echo; echo -e "  ${BOLD_MAGENTA}=======================================${DEFAULT_COLOR}"
echo -e "  ${BOLD_GREEN}Skrip Pembersihan Server Linux Selesai.${DEFAULT_COLOR}"
echo -e "  ${YELLOW}Tinjau output untuk error atau langkah yang dilewati.${DEFAULT_COLOR}"
