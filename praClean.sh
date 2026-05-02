#!/usr/bin/env bash
# PRA CLEAN Utility
# Kompatibel: Debian/Ubuntu dengan systemd

set -Eeuo pipefail

VERSION="1.1.0"
DRY_RUN=0
AI_ENABLED=1

# ========== Warna ==========
if [ -t 1 ]; then
  DEFAULT_COLOR='\e[0m'; RED='\e[0;31m'; GREEN='\e[0;32m'; YELLOW='\e[0;33m'; BLUE='\e[0;34m'; MAGENTA='\e[0;35m'; CYAN='\e[0;36m'
  BOLD_RED='\e[1;31m'; BOLD_GREEN='\e[1;32m'; BOLD_YELLOW='\e[1;33m'; BOLD_BLUE='\e[1;34m'; BOLD_MAGENTA='\e[1;35m'; BOLD_CYAN='\e[1;36m'; BOLD_WHITE='\e[1;37m'
else
  DEFAULT_COLOR=''; RED=''; GREEN=''; YELLOW=''; BLUE=''; MAGENTA=''; CYAN=''
  BOLD_RED=''; BOLD_GREEN=''; BOLD_YELLOW=''; BOLD_BLUE=''; BOLD_MAGENTA=''; BOLD_CYAN=''; BOLD_WHITE=''
fi

INFO_PREFIX="${BOLD_BLUE}[INFO]${DEFAULT_COLOR}"
WARNING_PREFIX="${BOLD_YELLOW}[PERINGATAN]${DEFAULT_COLOR}"
ERROR_PREFIX="${BOLD_RED}[ERROR]${DEFAULT_COLOR}"
SUCCESS_PREFIX="${BOLD_GREEN}[BERHASIL]${DEFAULT_COLOR}"
SKIPPED_PREFIX="${YELLOW}[DILEWATI]${DEFAULT_COLOR}"
QUESTION_PREFIX="${BOLD_CYAN}[PERTANYAAN]${DEFAULT_COLOR}"
AI_PREFIX="${BOLD_MAGENTA}[AI GEMINI]${DEFAULT_COLOR}"
DRY_PREFIX="${BOLD_YELLOW}[DRY-RUN]${DEFAULT_COLOR}"

# ========== AI ==========
GEMINI_API_KEY="${PRA_CLEAN_GEMINI_API_KEY:-${GEMINI_API_KEY:-}}"
GEMINI_API_ENDPOINT="https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash-latest:generateContent"
AI_DEPENDENCIES_MET=0
GLOW_INSTALLED=0

# ========== Util ==========
cleanup_cursor() { [ -t 1 ] && command -v tput >/dev/null 2>&1 && tput cnorm || true; }
trap cleanup_cursor EXIT INT TERM

has_cmd() { command -v "$1" >/dev/null 2>&1; }

usage() {
  cat <<EOF
PRA CLEAN Utility v${VERSION}

Usage:
  sudo -E ./praClean.sh [opsi]

Opsi:
  --dry-run    Tampilkan aksi tanpa menghapus/mengubah sistem
  --no-ai      Nonaktifkan fitur Gemini AI
  -h, --help   Tampilkan bantuan

Environment:
  PRA_CLEAN_GEMINI_API_KEY   API key Gemini opsional
EOF
}

parse_args() {
  while (($#)); do
    case "$1" in
      --dry-run) DRY_RUN=1 ;;
      --no-ai) AI_ENABLED=0 ;;
      -h|--help) usage; exit 0 ;;
      *) echo -e "${ERROR_PREFIX} Opsi tidak dikenal: $1"; usage; exit 2 ;;
    esac
    shift
  done
}

safe_clear() { [ -t 1 ] && command clear || true; }

confirm() {
  local message="$1" answer
  read -r -p "$(echo -e "  ${QUESTION_PREFIX} ${message} (${BOLD_GREEN}yes${DEFAULT_COLOR}/${BOLD_RED}NO${DEFAULT_COLOR}): ")" answer || true
  [[ "${answer:-}" == "yes" ]]
}

prompt_default() {
  local message="$1" default_value="$2" answer
  read -r -p "$(echo -e "  ${QUESTION_PREFIX} ${message} [${default_value}]: ")" answer || true
  printf '%s' "${answer:-$default_value}"
}

press_enter() {
  read -r -p "$(echo -e "  ${YELLOW}Tekan Enter untuk kembali...${DEFAULT_COLOR}")" _ || true
}

run_cmd() {
  if (( DRY_RUN )); then
    printf '  %b ' "$DRY_PREFIX"
    printf '%q ' "$@"
    printf '\n'
    return 0
  fi
  "$@"
}

run_as_user() {
  local target_user="$1"
  shift
  if [ -z "$target_user" ] || [ "$target_user" = "root" ]; then
    run_cmd "$@"
  else
    run_cmd sudo -u "$target_user" -- "$@"
  fi
}

current_login_user() { printf '%s' "${SUDO_USER:-root}"; }

user_home_dir() {
  local user_name="$1"
  getent passwd "$user_name" | cut -d: -f6
}

is_valid_size() { [[ "$1" =~ ^[1-9][0-9]*[KMGTP]?$ ]]; }
is_valid_time() { [[ "$1" =~ ^[1-9][0-9]*[smhdw]$ ]]; }
is_valid_positive_int() { [[ "$1" =~ ^[1-9][0-9]*$ ]]; }
is_valid_package_name() { [[ "$1" =~ ^[A-Za-z0-9][A-Za-z0-9+.-]*(:[A-Za-z0-9][A-Za-z0-9_-]*)?$ ]]; }

print_section() { echo -e "\n  ${BOLD_CYAN}$1${DEFAULT_COLOR}"; }

show_loading_animation() {
  (( DRY_RUN )) && { echo -e "  ${DRY_PREFIX} Mode simulasi aktif: sistem tidak akan diubah."; return; }
  command -v tput >/dev/null 2>&1 && tput civis || true
  local spin='|/-\' index=0 end_time=$((SECONDS+1))
  while (( SECONDS < end_time )); do
    printf "  ${BOLD_CYAN}Memuat PRA CLEAN Utility %c ${DEFAULT_COLOR}\r" "${spin:index++%4:1}"
    sleep 0.1
  done
  printf "                                        \r"
  cleanup_cursor
  echo
}

# ========== AI helpers ==========
check_ai_dependencies() {
  (( AI_ENABLED )) || { AI_DEPENDENCIES_MET=0; return; }

  local ok=1
  has_cmd curl || { echo -e "  ${YELLOW}Fitur AI butuh 'curl'.${DEFAULT_COLOR}"; ok=0; }
  has_cmd jq || { echo -e "  ${YELLOW}Fitur AI butuh 'jq'.${DEFAULT_COLOR}"; ok=0; }
  AI_DEPENDENCIES_MET=$ok
  has_cmd glow && GLOW_INSTALLED=1 || GLOW_INSTALLED=0

  if (( ! AI_DEPENDENCIES_MET )); then
    echo -e "  ${WARNING_PREFIX} Dependensi AI belum lengkap. Fitur AI dilewati."
  fi
}

ensure_gemini_api_key() {
  (( AI_ENABLED && AI_DEPENDENCIES_MET )) || return 1
  [ -n "${GEMINI_API_KEY:-}" ] && return 0

  local answer entered_key
  read -r -p "$(echo -e "  ${QUESTION_PREFIX} API key Gemini kosong. Isi sekarang? (${BOLD_GREEN}y${DEFAULT_COLOR}/N): ")" answer || true
  [[ "${answer:-}" =~ ^[Yy]$ ]] || return 1
  read -r -s -p "$(echo -e "  ${QUESTION_PREFIX} Masukkan API key Gemini: ")" entered_key || true
  echo
  [ -n "${entered_key:-}" ] || return 1
  GEMINI_API_KEY="$entered_key"
}

ask_ai_gemini() {
  local prompt_text="$1" payload_file config_file response err msg
  ensure_gemini_api_key || { echo -e "  ${SKIPPED_PREFIX} AI dilewati."; return 1; }

  if (( DRY_RUN )); then
    echo -e "  ${DRY_PREFIX} AI prompt tidak dikirim."
    return 0
  fi

  payload_file=$(mktemp)
  config_file=$(mktemp)
  chmod 600 "$payload_file" "$config_file"

  jq -n --arg prompt "$prompt_text" '{contents:[{parts:[{text:$prompt}]}],generationConfig:{temperature:0.4,maxOutputTokens:2048}}' >"$payload_file"
  cat >"$config_file" <<EOF
url = "${GEMINI_API_ENDPOINT}"
request = "POST"
header = "Content-Type: application/json"
header = "x-goog-api-key: ${GEMINI_API_KEY}"
data-binary = "@${payload_file}"
connect-timeout = 10
max-time = 60
silent
show-error
fail-with-body
EOF

  echo -e "  ${INFO_PREFIX} Menghubungi AI Gemini..."
  command -v tput >/dev/null 2>&1 && tput civis || true
  response=$(curl --config "$config_file" 2>&1) || {
    cleanup_cursor
    rm -f "$payload_file" "$config_file"
    echo -e "  ${ERROR_PREFIX} Gagal menghubungi Gemini: $response"
    return 1
  }
  cleanup_cursor
  rm -f "$payload_file" "$config_file"

  err=$(printf '%s' "$response" | jq -r '.error.message // empty' 2>/dev/null || true)
  if [ -n "$err" ]; then
    echo -e "  ${ERROR_PREFIX} API Gemini: $err"
    return 1
  fi

  msg=$(printf '%s' "$response" | jq -r '.candidates[0].content.parts[0].text // empty' 2>/dev/null || true)
  if [ -z "$msg" ]; then
    echo -e "  ${WARNING_PREFIX} Respons AI kosong/tidak valid."
    return 1
  fi

  echo -e "\n  ${AI_PREFIX} Respons AI:"
  echo -e "${CYAN}---------------------------------------------------------------------${DEFAULT_COLOR}"
  if (( GLOW_INSTALLED )); then
    printf '%s\n' "$msg" | glow -s dark -w "$(( $(tput cols 2>/dev/null || echo 120) - 8 ))"
  else
    printf '%s\n' "$msg" | sed 's/^/    /'
  fi
  echo -e "${CYAN}---------------------------------------------------------------------${DEFAULT_COLOR}"
}

# ========== Root check ==========
check_sudo() {
  if [[ "${EUID}" -ne 0 ]]; then
    echo -e "${WARNING_PREFIX} Skrip ini memerlukan hak akses root."
    echo -e "${INFO_PREFIX} Jalankan: sudo -E $0"
    exit 1
  fi
}

# ========== Header ==========
show_ascii_art() {
  echo -e "${BOLD_GREEN}"
  cat <<'EOF'
        PPPP   RRRR    AAA       CCCC  L      EEEEEE  AAA   NN   NN
        P   P  R   R  A   A     C      L      E      A   A  N N  N
        PPPP   RRRR   AAAAA     C      L      EEEE   AAAAA  N  N N
        P      R  R  A     A     C      L      E      A   A  N   NN
        P      R   R A       A   CCCC  LLLLL  EEEEEE A     A N    N
EOF
  echo -e "${DEFAULT_COLOR}"
  echo -e "${BOLD_MAGENTA}=======================================================================${DEFAULT_COLOR}"
  echo -e "${BOLD_MAGENTA}                    PRA CLEAN UTILITY v${VERSION}                    ${DEFAULT_COLOR}"
  echo -e "${BOLD_MAGENTA}=======================================================================${DEFAULT_COLOR}"
  echo -e "${CYAN}                        Developed by: jayyidsptr                       ${DEFAULT_COLOR}"
  echo -e "${CYAN}                 https://github.com/jayyidsptr                          ${DEFAULT_COLOR}"
  (( DRY_RUN )) && echo -e "${YELLOW}                         Mode simulasi aktif                         ${DEFAULT_COLOR}"
  (( AI_ENABLED )) && [ -n "${GEMINI_API_KEY:-}" ] && echo -e "${BLUE}                         AI Gemini siap                              ${DEFAULT_COLOR}"
  echo
}

# ========== Aksi pembersihan ==========
clean_apt() {
  print_section "Pembersihan APT"
  if (( DRY_RUN )); then
    run_cmd apt-get -y autoclean
    run_cmd apt-get -y clean
    run_cmd apt-get -y autoremove
  else
    run_cmd apt-get -y autoclean
    run_cmd apt-get -y clean
    run_cmd apt-get -y autoremove
  fi
  echo -e "  ${SUCCESS_PREFIX} Pembersihan APT selesai."
  press_enter
}

remove_specific_packages() {
  local input packages=() package invalid=()
  print_section "Hapus Paket Tertentu"
  read -r -p "$(echo -e "  ${QUESTION_PREFIX} Nama paket (pisahkan spasi, kosong=batal): ")" input || true
  [ -n "${input:-}" ] || { echo -e "  ${SKIPPED_PREFIX} Tidak ada paket."; press_enter; return; }

  read -r -a packages <<<"$input"
  for package in "${packages[@]}"; do
    is_valid_package_name "$package" || invalid+=("$package")
  done
  if ((${#invalid[@]})); then
    echo -e "  ${ERROR_PREFIX} Nama paket tidak valid: ${invalid[*]}"
    press_enter
    return
  fi

  if confirm "Minta AI jelaskan risiko hapus paket ini"; then
    ask_ai_gemini "Jelaskan fungsi dan risiko menghapus paket berikut di Ubuntu/Debian: ${packages[*]}. Beri jawaban praktis dan sebutkan dependensi yang perlu dicek."
  fi

  echo -e "  ${WARNING_PREFIX} Paket akan dihapus: ${BOLD_YELLOW}${packages[*]}${DEFAULT_COLOR}"
  if confirm "YAKIN hapus paket di atas"; then
    run_cmd apt-get -y remove -- "${packages[@]}"
    echo -e "  ${SUCCESS_PREFIX} Penghapusan paket selesai."
  else
    echo -e "  ${SKIPPED_PREFIX} Dibatalkan."
  fi
  press_enter
}

clean_var_log() {
  print_section "Pembersihan /var/log"
  echo -e "  ${CYAN}- Truncate file log aktif, kecuali wtmp/btmp/lastlog${DEFAULT_COLOR}"
  echo -e "  ${CYAN}- Hapus arsip log lama: *.gz, *.xz, *.zst, *.1, *.old${DEFAULT_COLOR}"

  if ! confirm "Lanjutkan pembersihan /var/log"; then
    echo -e "  ${SKIPPED_PREFIX} Pembersihan /var/log dilewati."
    press_enter
    return
  fi

  if (( DRY_RUN )); then
    echo -e "  ${DRY_PREFIX} File log aktif yang akan di-truncate:"
    find /var/log -type f ! -name 'wtmp' ! -name 'btmp' ! -name 'lastlog' ! \( -name '*.gz' -o -name '*.xz' -o -name '*.zst' -o -name '*.1' -o -name '*.old' \) -print 2>/dev/null | sed 's/^/    /'
    echo -e "  ${DRY_PREFIX} Arsip log yang akan dihapus:"
    find /var/log -type f \( -name '*.gz' -o -name '*.xz' -o -name '*.zst' -o -name '*.1' -o -name '*.old' \) -print 2>/dev/null | sed 's/^/    /'
  else
    find /var/log -type f \
      ! -name 'wtmp' ! -name 'btmp' ! -name 'lastlog' \
      -exec sh -c 'case "$1" in *.gz|*.xz|*.zst|*.1|*.old) rm -f -- "$1";; *) : > "$1";; esac' _ {} \;
  fi
  echo -e "  ${SUCCESS_PREFIX} /var/log selesai diproses."
  press_enter
}

set_journald_value() {
  local conf="$1" key="$2" value="$3"
  if grep -q "^${key}=" "$conf"; then
    run_cmd sed -i "s/^${key}=.*/${key}=${value}/" "$conf"
  elif grep -q '^\[Journal\]' "$conf"; then
    if (( DRY_RUN )); then
      echo -e "  ${DRY_PREFIX} Tambah ${key}=${value} ke $conf"
    else
      sed -i "/^\[Journal\]/a ${key}=${value}" "$conf"
    fi
  else
    if (( DRY_RUN )); then
      echo -e "  ${DRY_PREFIX} Tambah [Journal] dan ${key}=${value} ke $conf"
    else
      printf '\n[Journal]\n%s=%s\n' "$key" "$value" >>"$conf"
    fi
  fi
}

configure_clean_journald() {
  local conf=/etc/systemd/journald.conf current_use current_file change max_use max_file vacuum_time vacuum_size backup
  print_section "Konfigurasi & Vacuum Journald"

  current_use=$(grep -Po '^SystemMaxUse=\K.*' "$conf" 2>/dev/null || echo "Tidak diatur")
  current_file=$(grep -Po '^SystemMaxFileSize=\K.*' "$conf" 2>/dev/null || echo "Tidak diatur")
  echo -e "  ${CYAN}Saat ini: SystemMaxUse=${BOLD_YELLOW}${current_use}${DEFAULT_COLOR}, SystemMaxFileSize=${BOLD_YELLOW}${current_file}${DEFAULT_COLOR}"

  read -r -p "$(echo -e "  ${QUESTION_PREFIX} Ubah batas ukuran journald? (${BOLD_GREEN}y${DEFAULT_COLOR}/N): ")" change || true
  if [[ "${change:-}" =~ ^[Yy]$ ]]; then
    read -r -p "$(echo -e "  ${QUESTION_PREFIX} SystemMaxUse (mis: 1G, kosong=skip): ")" max_use || true
    read -r -p "$(echo -e "  ${QUESTION_PREFIX} SystemMaxFileSize (mis: 50M, kosong=skip): ")" max_file || true

    [ -n "${max_use:-}" ] && ! is_valid_size "$max_use" && { echo -e "  ${ERROR_PREFIX} SystemMaxUse tidak valid."; max_use=""; }
    [ -n "${max_file:-}" ] && ! is_valid_size "$max_file" && { echo -e "  ${ERROR_PREFIX} SystemMaxFileSize tidak valid."; max_file=""; }

    if [ -n "${max_use:-}" ] || [ -n "${max_file:-}" ]; then
      if [ ! -f "$conf" ] && (( ! DRY_RUN )); then
        printf '[Journal]\n' >"$conf"
      fi
      backup="${conf}.praclean.$(date +%Y%m%d%H%M%S).bak"
      [ -f "$conf" ] && run_cmd cp -a "$conf" "$backup"
      [ -n "${max_use:-}" ] && set_journald_value "$conf" "SystemMaxUse" "$max_use"
      [ -n "${max_file:-}" ] && set_journald_value "$conf" "SystemMaxFileSize" "$max_file"
      run_cmd systemctl restart systemd-journald
    fi
  fi

  read -r -p "$(echo -e "  ${QUESTION_PREFIX} Vacuum berdasarkan waktu (mis: 2d, kosong=skip): ")" vacuum_time || true
  if [ -n "${vacuum_time:-}" ]; then
    if is_valid_time "$vacuum_time"; then
      run_cmd journalctl --vacuum-time="$vacuum_time"
    else
      echo -e "  ${ERROR_PREFIX} Format waktu tidak valid."
    fi
  fi

  read -r -p "$(echo -e "  ${QUESTION_PREFIX} Vacuum berdasarkan ukuran (mis: 200M, kosong=skip): ")" vacuum_size || true
  if [ -n "${vacuum_size:-}" ]; then
    if is_valid_size "$vacuum_size"; then
      run_cmd journalctl --vacuum-size="$vacuum_size"
    else
      echo -e "  ${ERROR_PREFIX} Format ukuran tidak valid."
    fi
  fi

  echo -e "  ${SUCCESS_PREFIX} Journald selesai diproses."
  press_enter
}

clean_tmp_files() {
  local days all_answer
  print_section "Pembersihan /tmp"
  echo -e "  ${WARNING_PREFIX} Default aman: hapus item /tmp lebih tua dari N hari."
  days=$(prompt_default "Hapus item lebih tua dari berapa hari" "7")
  if ! is_valid_positive_int "$days"; then
    echo -e "  ${ERROR_PREFIX} Jumlah hari tidak valid."
    press_enter
    return
  fi

  read -r -p "$(echo -e "  ${QUESTION_PREFIX} Paksa hapus SEMUA isi /tmp? (${BOLD_RED}berisiko${DEFAULT_COLOR}) (${BOLD_GREEN}yes${DEFAULT_COLOR}/NO): ")" all_answer || true
  if [[ "${all_answer:-}" == "yes" ]]; then
    if confirm "Konfirmasi ulang: hapus SEMUA isi /tmp"; then
      if (( DRY_RUN )); then
        echo -e "  ${DRY_PREFIX} Item /tmp kandidat hapus:"
        find /tmp -xdev -mindepth 1 -maxdepth 1 -print 2>/dev/null | sed 's/^/    /'
      else
        find /tmp -xdev -mindepth 1 -maxdepth 1 -exec rm -rf -- {} +
      fi
    else
      echo -e "  ${SKIPPED_PREFIX} Hapus semua /tmp dibatalkan."
    fi
  else
    if (( DRY_RUN )); then
      echo -e "  ${DRY_PREFIX} Item /tmp kandidat hapus:"
      find /tmp -xdev -mindepth 1 -maxdepth 1 -mtime +"$days" -print 2>/dev/null | sed 's/^/    /'
    else
      find /tmp -xdev -mindepth 1 -maxdepth 1 -mtime +"$days" -exec rm -rf -- {} +
    fi
  fi
  echo -e "  ${SUCCESS_PREFIX} /tmp selesai diproses."
  press_enter
}

clean_user_cache() {
  local target_user user_home user_cache_dir days
  print_section "Pembersihan Cache Pengguna"
  target_user=$(current_login_user)
  user_home=$(user_home_dir "$target_user" || true)
  user_cache_dir="${user_home:-/root}/.cache"

  if [ ! -d "$user_cache_dir" ]; then
    echo -e "  ${WARNING_PREFIX} Direktori cache tidak ditemukan: $user_cache_dir"
    press_enter
    return
  fi

  echo -e "  ${INFO_PREFIX} User: ${BOLD_YELLOW}${target_user}${DEFAULT_COLOR}"
  echo -e "  ${INFO_PREFIX} Cache: ${BOLD_YELLOW}${user_cache_dir}${DEFAULT_COLOR}"
  echo -e "  ${CYAN}10 item terbesar:${DEFAULT_COLOR}"
  du -sh "$user_cache_dir"/* 2>/dev/null | sort -hr | head -n 10 | sed 's/^/    /' || true

  days=$(prompt_default "Hapus cache lebih tua dari berapa hari" "30")
  if ! is_valid_positive_int "$days"; then
    echo -e "  ${ERROR_PREFIX} Jumlah hari tidak valid."
    press_enter
    return
  fi

  if confirm "Lanjut hapus cache lebih tua dari ${days} hari"; then
    if (( DRY_RUN )); then
      echo -e "  ${DRY_PREFIX} Kandidat hapus:"
      find "$user_cache_dir" -mindepth 1 -maxdepth 1 -mtime +"$days" -print 2>/dev/null | sed 's/^/    /'
    else
      run_as_user "$target_user" find "$user_cache_dir" -mindepth 1 -maxdepth 1 -mtime +"$days" -exec rm -rf -- {} +
    fi
    echo -e "  ${SUCCESS_PREFIX} Cache pengguna selesai diproses."
  else
    echo -e "  ${SKIPPED_PREFIX} Pembersihan cache dilewati."
  fi
  press_enter
}

# ========== Cache aplikasi ==========
clean_npm_cache() {
  local target_user
  print_section "Pembersihan Cache NPM"
  has_cmd npm || { echo -e "  ${SKIPPED_PREFIX} npm tidak ditemukan."; press_enter; return; }
  target_user=$(current_login_user)
  run_as_user "$target_user" npm cache verify || true
  if confirm "Lanjut npm cache clean --force"; then
    run_as_user "$target_user" npm cache clean --force
    run_as_user "$target_user" npm cache verify || true
  fi
  press_enter
}

clean_pip3_cache() {
  local target_user
  print_section "Pembersihan Cache Pip3"
  has_cmd pip3 || { echo -e "  ${SKIPPED_PREFIX} pip3 tidak ditemukan."; press_enter; return; }
  target_user=$(current_login_user)
  run_as_user "$target_user" pip3 cache info || true
  if confirm "Lanjut pip3 cache purge"; then
    run_as_user "$target_user" pip3 cache purge || true
  fi
  press_enter
}

clean_go_cache() {
  local target_user go_cache_dir
  print_section "Pembersihan Cache Go"
  has_cmd go || { echo -e "  ${SKIPPED_PREFIX} go tidak ditemukan."; press_enter; return; }
  target_user=$(current_login_user)
  go_cache_dir=$(sudo -u "$target_user" -- go env GOCACHE 2>/dev/null || true)
  [ -n "$go_cache_dir" ] && [ -d "$go_cache_dir" ] && du -sh "$go_cache_dir" 2>/dev/null | sed 's/^/    /' || true
  if confirm "Lanjut go clean -cache -modcache"; then
    run_as_user "$target_user" go clean -cache
    run_as_user "$target_user" go clean -modcache
  fi
  press_enter
}

clean_maven_cache() {
  local target_user user_home repo
  print_section "Pembersihan Cache Maven"
  target_user=$(current_login_user)
  user_home=$(user_home_dir "$target_user" || true)
  repo="${user_home:-/root}/.m2/repository"
  [ -d "$repo" ] || { echo -e "  ${SKIPPED_PREFIX} $repo tidak ditemukan."; press_enter; return; }
  du -sh "$repo" 2>/dev/null | sed 's/^/    /' || true
  if confirm "Lanjut hapus repositori Maven lokal"; then
    run_as_user "$target_user" rm -rf -- "$repo"
  fi
  press_enter
}

clean_gradle_cache() {
  local target_user user_home caches
  print_section "Pembersihan Cache Gradle"
  target_user=$(current_login_user)
  user_home=$(user_home_dir "$target_user" || true)
  caches="${user_home:-/root}/.gradle/caches"
  [ -d "$caches" ] || { echo -e "  ${SKIPPED_PREFIX} $caches tidak ditemukan."; press_enter; return; }
  du -sh "$caches" 2>/dev/null | sed 's/^/    /' || true
  has_cmd gradle && run_as_user "$target_user" gradle --stop >/dev/null 2>&1 || true
  if confirm "Lanjut hapus cache Gradle"; then
    run_as_user "$target_user" rm -rf -- "$caches"
  fi
  press_enter
}

# ========== Docker ==========
clean_docker() {
  print_section "Pembersihan Docker"
  has_cmd docker || { echo -e "  ${SKIPPED_PREFIX} docker tidak ditemukan."; press_enter; return; }

  docker system df 2>/dev/null | sed 's/^/    /' || true

  if confirm "Hapus dangling images (docker image prune)"; then
    run_cmd docker image prune -f
  fi
  if confirm "Hapus semua image tidak terpakai (docker image prune -a)"; then
    run_cmd docker image prune -a -f
  fi
  if confirm "Hapus container berhenti, network tak terpakai, build cache ringan (docker system prune)"; then
    run_cmd docker system prune -f
  fi
  if confirm "Hapus volume Docker tidak terpakai (data bisa hilang)"; then
    run_cmd docker volume prune -f
  fi
  if confirm "Hapus semua builder cache (docker builder prune -a)"; then
    run_cmd docker builder prune -a -f
  fi

  echo -e "  ${SUCCESS_PREFIX} Docker selesai diproses."
  press_enter
}

# ========== Utilitas sistem ==========
analyze_disk_usage() {
  local path answer
  print_section "Analisis Penggunaan Disk"
  echo -e "  ${CYAN}Filesystem:${DEFAULT_COLOR}"
  df -h | sed 's/^/    /'
  echo -e "\n  ${CYAN}Top direktori root:${DEFAULT_COLOR}"
  du -xh --max-depth=1 / 2>/dev/null | sort -rh | head -n 15 | sed 's/^/    /'

  read -r -p "$(echo -e "  ${QUESTION_PREFIX} Path spesifik (kosong=skip): ")" path || true
  if [ -n "${path:-}" ]; then
    if [ -d "$path" ]; then
      echo -e "  ${CYAN}Top item di ${path}:${DEFAULT_COLOR}"
      du -xh --max-depth=1 "$path" 2>/dev/null | sort -rh | head -n 20 | sed 's/^/    /'
      read -r -p "$(echo -e "  ${QUESTION_PREFIX} Minta saran AI untuk path ini? (${BOLD_GREEN}y${DEFAULT_COLOR}/N): ")" answer || true
      [[ "${answer:-}" =~ ^[Yy]$ ]] && ask_ai_gemini "Beri saran aman mengosongkan ruang pada path: $path. Pisahkan file aman dihapus, perlu backup, dan jangan disentuh."
    else
      echo -e "  ${ERROR_PREFIX} Direktori tidak ditemukan: $path"
    fi
  fi
  press_enter
}

review_system_logs() {
  local log_file lines custom choice analyze snippet
  print_section "Tinjau Log Sistem"
  echo -e "  ${BOLD_YELLOW}1.${DEFAULT_COLOR} /var/log/syslog"
  echo -e "  ${BOLD_YELLOW}2.${DEFAULT_COLOR} /var/log/auth.log"
  echo -e "  ${BOLD_YELLOW}3.${DEFAULT_COLOR} /var/log/kern.log"
  echo -e "  ${BOLD_YELLOW}4.${DEFAULT_COLOR} /var/log/dpkg.log"
  echo -e "  ${BOLD_YELLOW}5.${DEFAULT_COLOR} Path kustom"
  echo -e "  ${BOLD_YELLOW}0.${DEFAULT_COLOR} Kembali"
  read -r -p "$(echo -e "  ${BOLD_WHITE}Pilihan [0-5]: ${DEFAULT_COLOR}")" choice || true

  case "${choice:-}" in
    1) log_file="/var/log/syslog" ;;
    2) log_file="/var/log/auth.log" ;;
    3) log_file="/var/log/kern.log" ;;
    4) log_file="/var/log/dpkg.log" ;;
    5) read -r -p "$(echo -e "  ${QUESTION_PREFIX} Path lengkap: ")" custom || true; log_file="$custom" ;;
    0) return ;;
    *) echo -e "  ${ERROR_PREFIX} Pilihan tidak valid."; press_enter; return ;;
  esac

  [ -f "$log_file" ] || { echo -e "  ${ERROR_PREFIX} File tidak ditemukan: $log_file"; press_enter; return; }
  lines=$(prompt_default "Jumlah baris terakhir" "30")
  is_valid_positive_int "$lines" || lines=30
  tail -n "$lines" "$log_file" | sed 's/^/    /'

  read -r -p "$(echo -e "  ${QUESTION_PREFIX} Analisis AI untuk log ini? (${BOLD_GREEN}y${DEFAULT_COLOR}/N): ")" analyze || true
  if [[ "${analyze:-}" =~ ^[Yy]$ ]]; then
    snippet=$(tail -n "$lines" "$log_file")
    ask_ai_gemini "Analisis potongan log berikut. Ringkas error/warning, kemungkinan sebab, dan aksi aman:\n\`\`\`\n${snippet}\n\`\`\`"
  fi
  press_enter
}

# ========== Menu ==========
submenu_app_cache_cleanup() {
  local choice
  while true; do
    safe_clear; show_ascii_art
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
    read -r -p "$(echo -e "  ${BOLD_WHITE}Pilihan [0-5]: ${DEFAULT_COLOR}")" choice || true
    case "${choice:-}" in
      1) safe_clear; clean_npm_cache ;;
      2) safe_clear; clean_pip3_cache ;;
      3) safe_clear; clean_go_cache ;;
      4) safe_clear; clean_maven_cache ;;
      5) safe_clear; clean_gradle_cache ;;
      0) break ;;
      *) echo -e "  ${ERROR_PREFIX} Pilihan tidak valid."; sleep 1 ;;
    esac
  done
}

submenu_system_utilities() {
  local choice
  while true; do
    safe_clear; show_ascii_art
    echo -e "  ╭────────────────────────────────────────────────────╮"
    echo -e "  │ ${BOLD_WHITE}Utilitas Sistem${DEFAULT_COLOR}                                  │"
    echo -e "  ├────────────────────────────────────────────────────┤"
    echo -e "  │ ${BOLD_YELLOW}1.${DEFAULT_COLOR} Analisis Penggunaan Disk ${CYAN}(AI)${DEFAULT_COLOR}                   │"
    echo -e "  │ ${BOLD_YELLOW}2.${DEFAULT_COLOR} Tinjau Log Sistem Penting ${CYAN}(AI)${DEFAULT_COLOR}                  │"
    echo -e "  │ ${BOLD_YELLOW}0.${DEFAULT_COLOR} ${BOLD_RED}Kembali${DEFAULT_COLOR}                                   │"
    echo -e "  ╰────────────────────────────────────────────────────╯"
    read -r -p "$(echo -e "  ${BOLD_WHITE}Pilihan [0-2]: ${DEFAULT_COLOR}")" choice || true
    case "${choice:-}" in
      1) safe_clear; analyze_disk_usage ;;
      2) safe_clear; review_system_logs ;;
      0) break ;;
      *) echo -e "  ${ERROR_PREFIX} Pilihan tidak valid."; sleep 1 ;;
    esac
  done
}

run_all_cleanup() {
  local steps step
  safe_clear; show_ascii_art
  echo -e "  ${INFO_PREFIX} Jalankan pembersihan utama berurutan."
  echo -e "  ${WARNING_PREFIX} Setiap langkah tetap punya konfirmasi sendiri."
  confirm "Lanjutkan" || { echo -e "  ${SKIPPED_PREFIX} Operasi dibatalkan."; press_enter; return; }
  steps=(clean_apt clean_var_log configure_clean_journald clean_tmp_files clean_user_cache clean_docker)
  for step in "${steps[@]}"; do
    safe_clear; show_ascii_art
    echo -e "  ${BOLD_CYAN}>>> ${step//_/ } <<<${DEFAULT_COLOR}"
    "$step"
  done
  echo -e "  ${SUCCESS_PREFIX} Semua pembersihan utama selesai."
  press_enter
}

show_main_menu() {
  safe_clear; show_ascii_art
  echo -e "  ╭───────────────────────────────────────────────────────────╮"
  echo -e "  │ ${BOLD_WHITE}Pilih opsi pembersihan atau utilitas:${DEFAULT_COLOR}                     │"
  echo -e "  ├───────────────────────────────────────────────────────────┤"
  echo -e "  │ ${BOLD_YELLOW}Pembersihan Sistem Umum:${DEFAULT_COLOR}                                  │"
  echo -e "  │   ${BOLD_YELLOW}1.${DEFAULT_COLOR} Bersihkan Cache APT                                  │"
  echo -e "  │   ${BOLD_YELLOW}2.${DEFAULT_COLOR} Hapus Paket Tertentu ${CYAN}(AI opsional)${DEFAULT_COLOR}              │"
  echo -e "  │   ${BOLD_YELLOW}3.${DEFAULT_COLOR} Bersihkan Log (/var/log)                            │"
  echo -e "  │   ${BOLD_YELLOW}4.${DEFAULT_COLOR} Konfigurasi & Vacuum Journald                       │"
  echo -e "  │   ${BOLD_YELLOW}5.${DEFAULT_COLOR} Hapus File Sementara (/tmp)                         │"
  echo -e "  │   ${BOLD_YELLOW}6.${DEFAULT_COLOR} Bersihkan Cache Pengguna (~/.cache)                 │"
  echo -e "  │ ${BOLD_YELLOW}Pembersihan Cache Aplikasi:${DEFAULT_COLOR}                               │"
  echo -e "  │   ${BOLD_YELLOW}7.${DEFAULT_COLOR} NPM / Pip3 / Go / Maven / Gradle                    │"
  echo -e "  │ ${BOLD_YELLOW}Pembersihan Docker:${DEFAULT_COLOR}                                       │"
  echo -e "  │   ${BOLD_YELLOW}8.${DEFAULT_COLOR} Pembersihan Docker Bertahap                         │"
  echo -e "  │ ${BOLD_YELLOW}Utilitas Sistem:${DEFAULT_COLOR}                                          │"
  echo -e "  │   ${BOLD_YELLOW}9.${DEFAULT_COLOR} Analisis Disk & Tinjau Log ${CYAN}(AI opsional)${DEFAULT_COLOR}        │"
  echo -e "  ├───────────────────────────────────────────────────────────┤"
  echo -e "  │ ${BOLD_GREEN}13.${DEFAULT_COLOR} JALANKAN SEMUA Pembersihan Utama                      │"
  echo -e "  │ ${BOLD_RED} 0.${DEFAULT_COLOR} Keluar                                                   │"
  echo -e "  ╰───────────────────────────────────────────────────────────╯"
}

main() {
  local choice
  parse_args "$@"
  check_sudo
  show_loading_animation
  check_ai_dependencies

  while true; do
    show_main_menu
    read -r -p "$(echo -e "  ${BOLD_WHITE}Masukkan pilihan [0-9,13]: ${DEFAULT_COLOR}")" choice || true
    case "${choice:-}" in
      1) safe_clear; clean_apt ;;
      2) safe_clear; remove_specific_packages ;;
      3) safe_clear; clean_var_log ;;
      4) safe_clear; configure_clean_journald ;;
      5) safe_clear; clean_tmp_files ;;
      6) safe_clear; clean_user_cache ;;
      7) submenu_app_cache_cleanup ;;
      8) safe_clear; clean_docker ;;
      9) submenu_system_utilities ;;
      13) run_all_cleanup ;;
      0) echo -e "  ${BOLD_GREEN}Keluar. Sampai jumpa!${DEFAULT_COLOR}"; break ;;
      *) echo -e "  ${ERROR_PREFIX} Pilihan tidak valid."; sleep 1 ;;
    esac
  done

  echo
  echo -e "  ${BOLD_MAGENTA}=======================================${DEFAULT_COLOR}"
  echo -e "  ${BOLD_GREEN}Skrip Pembersihan Server Linux Selesai.${DEFAULT_COLOR}"
  echo -e "  ${YELLOW}Tinjau output untuk error atau langkah yang dilewati.${DEFAULT_COLOR}"
}

main "$@"
