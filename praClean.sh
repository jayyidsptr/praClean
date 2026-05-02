#!/usr/bin/env bash
# PRA CLEAN Utility
# Kompatibel: Debian/Ubuntu dengan systemd

set -Eeuo pipefail

VERSION="1.1.0"
DRY_RUN=0
AI_ENABLED=1

# ========== Warna ==========
if [ -t 1 ] && [ -z "${NO_COLOR:-}" ]; then
  DEFAULT_COLOR='\e[0m'; RED='\e[0;31m'; GREEN='\e[0;32m'; YELLOW='\e[0;33m'; BLUE='\e[0;34m'; MAGENTA='\e[0;35m'; CYAN='\e[0;36m'
  BOLD_RED='\e[1;31m'; BOLD_GREEN='\e[1;32m'; BOLD_YELLOW='\e[1;33m'; BOLD_BLUE='\e[1;34m'; BOLD_MAGENTA='\e[1;35m'; BOLD_CYAN='\e[1;36m'; BOLD_WHITE='\e[1;37m'
else
  DEFAULT_COLOR=''; RED=''; GREEN=''; YELLOW=''; BLUE=''; MAGENTA=''; CYAN=''
  BOLD_RED=''; BOLD_GREEN=''; BOLD_YELLOW=''; BOLD_BLUE=''; BOLD_MAGENTA=''; BOLD_CYAN=''; BOLD_WHITE=''
fi

UNICODE_UI=1
if [ "${PRA_CLEAN_ASCII:-0}" = "1" ] || [[ "${LC_ALL:-${LANG:-}}" != *UTF-8* && "${LC_ALL:-${LANG:-}}" != *utf8* ]]; then
  UNICODE_UI=0
fi

if (( UNICODE_UI )); then
  BOX_TL="╭"; BOX_TR="╮"; BOX_ML="├"; BOX_MR="┤"; BOX_BL="╰"; BOX_BR="╯"; BOX_H="─"; BOX_V="│"; MENU_CURSOR="❯"; MENU_SEP="—"
else
  BOX_TL="+"; BOX_TR="+"; BOX_ML="+"; BOX_MR="+"; BOX_BL="+"; BOX_BR="+"; BOX_H="-"; BOX_V="|"; MENU_CURSOR=">"; MENU_SEP="-"
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
MENU_CHOICE=""

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
  PRA_CLEAN_ASCII=1          Paksa tampilan ASCII untuk terminal lawas
  NO_COLOR=1                 Nonaktifkan warna terminal
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

term_cols() {
  local cols
  cols=$(tput cols 2>/dev/null || echo 80)
  is_valid_positive_int "${cols:-}" || cols=80
  printf '%s' "$cols"
}

ui_width() {
  local cols width
  cols=$(term_cols)
  if (( cols < 64 )); then
    width=$((cols - 4))
  elif (( cols > 96 )); then
    width=92
  else
    width=$((cols - 6))
  fi
  (( width < 42 )) && width=42
  printf '%s' "$width"
}

repeat_char() {
  local char="$1" count="$2" out=""
  while (( count-- > 0 )); do out+="$char"; done
  printf '%s' "$out"
}

plain_len() {
  local text="$1"
  text=$(printf '%s' "$text" | sed -E 's/\x1B\[[0-9;]*[A-Za-z]//g')
  printf '%s' "${#text}"
}

truncate_text() {
  local text="$1" max_len="$2"
  (( max_len <= 0 )) && { printf ''; return; }
  if (( ${#text} <= max_len )); then
    printf '%s' "$text"
  elif (( max_len <= 1 )); then
    printf '…'
  else
    printf '%s…' "${text:0:$((max_len - 1))}"
  fi
}

box_line() {
  local content="$1" width="${2:-$(ui_width)}" len pad
  len=$(plain_len "$content")
  pad=$((width - len - 4))
  (( pad < 0 )) && pad=0
  printf '  %b%s%b %b%b %b%s%b\n' "$CYAN" "$BOX_V" "$DEFAULT_COLOR" "$content" "$(repeat_char ' ' "$pad")" "$CYAN" "$BOX_V" "$DEFAULT_COLOR"
}

box_top() {
  local width="${1:-$(ui_width)}"
  printf '  %b%s%s%s%b\n' "$CYAN" "$BOX_TL" "$(repeat_char "$BOX_H" "$((width - 2))")" "$BOX_TR" "$DEFAULT_COLOR"
}

box_mid() {
  local width="${1:-$(ui_width)}"
  printf '  %b%s%s%s%b\n' "$CYAN" "$BOX_ML" "$(repeat_char "$BOX_H" "$((width - 2))")" "$BOX_MR" "$DEFAULT_COLOR"
}

box_bottom() {
  local width="${1:-$(ui_width)}"
  printf '  %b%s%s%s%b\n' "$CYAN" "$BOX_BL" "$(repeat_char "$BOX_H" "$((width - 2))")" "$BOX_BR" "$DEFAULT_COLOR"
}

center_line() {
  local text="$1" width="${2:-$(ui_width)}" inner len left right
  inner=$((width - 4))
  (( inner < 1 )) && inner=1
  len=$(plain_len "$text")
  left=$(((inner - len) / 2))
  (( left < 0 )) && left=0
  right=$((inner - len - left))
  (( right < 0 )) && right=0
  printf '%s%b%s' "$(repeat_char ' ' "$left")" "$text" "$(repeat_char ' ' "$right")"
}

badge() {
  local label="$1" color="$2"
  printf '%b[%s]%b' "$color" "$label" "$DEFAULT_COLOR"
}

menu_select() {
  local title="$1" selected=0 key rest choice count compact width footer next_key candidate inner_width
  shift
  local options=("$@")
  count=${#options[@]}
  width=$(ui_width)
  inner_width=$((width - 4))

  if [ ! -t 0 ]; then
    return 1
  fi

  while true; do
    safe_clear
    show_ascii_art
    compact=0
    (( width < 86 )) && compact=1

    box_top "$width"
    box_line "${BOLD_WHITE}${title}${DEFAULT_COLOR}" "$width"
    box_mid "$width"

    local index option value label desc marker number_color line plain_line max_label max_desc
    for index in "${!options[@]}"; do
      option="${options[$index]}"
      IFS='|' read -r value label desc <<<"$option"
      if (( index == selected )); then
        marker="${BOLD_CYAN}${MENU_CURSOR}${DEFAULT_COLOR}"
        number_color="$BOLD_GREEN"
      else
        marker=" "
        number_color="$YELLOW"
      fi

      if (( compact )); then
        max_label=$((inner_width - ${#value} - 4))
        label=$(truncate_text "$label" "$max_label")
        line="${marker} ${number_color}${value}.${DEFAULT_COLOR} ${label}"
      else
        plain_line="  ${value}. ${label} ${MENU_SEP} ${desc}"
        if (( ${#plain_line} > inner_width )); then
          max_desc=$((inner_width - ${#value} - ${#label} - 7))
          if (( max_desc < 10 )); then
            compact=1
            max_label=$((inner_width - ${#value} - 4))
            label=$(truncate_text "$label" "$max_label")
            line="${marker} ${number_color}${value}.${DEFAULT_COLOR} ${label}"
          else
            desc=$(truncate_text "$desc" "$max_desc")
            line="${marker} ${number_color}${value}.${DEFAULT_COLOR} ${label} ${CYAN}${MENU_SEP}${DEFAULT_COLOR} ${desc}"
          fi
        else
          line="${marker} ${number_color}${value}.${DEFAULT_COLOR} ${label} ${CYAN}${MENU_SEP}${DEFAULT_COLOR} ${desc}"
        fi
      fi
      box_line "$line" "$width"
    done

    box_mid "$width"
    if (( compact )); then
      footer="${YELLOW}↑↓ Enter • angka • q kembali${DEFAULT_COLOR}"
    else
      footer="${YELLOW}↑↓ navigasi • Enter pilih • angka shortcut • q kembali${DEFAULT_COLOR}"
    fi
    box_line "$footer" "$width"
    box_bottom "$width"

    IFS= read -rsn1 key || return 1
    case "$key" in
      "")
        IFS='|' read -r choice _ <<<"${options[$selected]}"
        MENU_CHOICE="$choice"
        return 0
        ;;
      [Qq]) MENU_CHOICE="0"; return 0 ;;
      [0-9])
        candidate="$key"
        IFS= read -rsn1 -t 0.18 next_key || next_key=""
        [[ "${next_key:-}" =~ ^[0-9]$ ]] && candidate+="$next_key"
        for option in "${options[@]}"; do
          IFS='|' read -r choice _ <<<"$option"
          if [ "$candidate" = "$choice" ]; then
            MENU_CHOICE="$choice"
            return 0
          fi
        done
        for option in "${options[@]}"; do
          IFS='|' read -r choice _ <<<"$option"
          if [ "$key" = "$choice" ]; then
            MENU_CHOICE="$choice"
            return 0
          fi
        done
        ;;
      $'\e')
        rest=""
        IFS= read -rsn2 -t 0.1 rest || true
        case "$rest" in
          '[A') selected=$(((selected - 1 + count) % count)) ;;
          '[B') selected=$(((selected + 1) % count)) ;;
          '[C')
            IFS='|' read -r choice _ <<<"${options[$selected]}"
            MENU_CHOICE="$choice"
            return 0
            ;;
          '[D') MENU_CHOICE="0"; return 0 ;;
        esac
        ;;
    esac
  done
}

prompt_menu_choice() {
  local title="$1" range="$2" choice
  shift 2
  MENU_CHOICE=""
  if [ -t 0 ]; then
    menu_select "$title" "$@"
  else
    read -r -p "$(echo -e "  ${BOLD_WHITE}Pilihan [${range}]: ${DEFAULT_COLOR}")" choice || true
    MENU_CHOICE="${choice:-}"
  fi
}

confirm() {
  local message="$1" answer selected=1 key rest yes_label no_label hint

  if [ ! -t 0 ]; then
    read -r -p "$(echo -e "  ${QUESTION_PREFIX} ${message} (${BOLD_GREEN}yes${DEFAULT_COLOR}/${BOLD_RED}NO${DEFAULT_COLOR}): ")" answer || true
    [[ "${answer:-}" == "yes" ]]
    return
  fi

  hint="${YELLOW}(↑/↓ atau ←/→, Enter pilih, y/n cepat)${DEFAULT_COLOR}"
  while true; do
    if (( selected == 0 )); then
      yes_label="${BOLD_GREEN}▶ YES ◀${DEFAULT_COLOR}"
      no_label="${RED}  NO   ${DEFAULT_COLOR}"
    else
      yes_label="${GREEN}  YES  ${DEFAULT_COLOR}"
      no_label="${BOLD_RED}▶ NO ◀${DEFAULT_COLOR}"
    fi

    printf '\r\033[K  %b %s  %b  %b  %b' "$QUESTION_PREFIX" "$message" "$yes_label" "$no_label" "$hint"
    IFS= read -rsn1 key || { echo; return 1; }

    case "$key" in
      "") echo; (( selected == 0 )); return ;;
      [Yy]) selected=0; echo; return 0 ;;
      [Nn]) selected=1; echo; return 1 ;;
      $'\e')
        rest=""
        IFS= read -rsn2 -t 0.1 rest || true
        case "$rest" in
          '[A'|'[B'|'[C'|'[D') selected=$((1 - selected)) ;;
          *) echo; return 1 ;;
        esac
        ;;
    esac
  done
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

  local entered_key
  confirm "API key Gemini kosong. Isi sekarang" || return 1
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
  local width cols subtitle status_line
  width=$(ui_width)
  cols=$(term_cols)
  subtitle="Linux cleanup • logs • Docker • AI assist"
  status_line="$(badge "v${VERSION}" "$BOLD_GREEN")  $(badge "sudo" "$BOLD_BLUE")"
  (( DRY_RUN )) && status_line+="  $(badge "dry-run" "$BOLD_YELLOW")"
  (( AI_ENABLED )) && [ -n "${GEMINI_API_KEY:-}" ] && status_line+="  $(badge "AI ready" "$BOLD_MAGENTA")"
  (( AI_ENABLED )) || status_line+="  $(badge "AI off" "$YELLOW")"

  box_top "$width"
  if (( UNICODE_UI && width >= 86 )); then
    box_line "${BOLD_GREEN}██████╗ ██████╗  █████╗      ██████╗██╗     ███████╗ █████╗ ███╗   ██╗${DEFAULT_COLOR}" "$width"
    box_line "${BOLD_GREEN}██╔══██╗██╔══██╗██╔══██╗    ██╔════╝██║     ██╔════╝██╔══██╗████╗  ██║${DEFAULT_COLOR}" "$width"
    box_line "${BOLD_GREEN}██████╔╝██████╔╝███████║    ██║     ██║     █████╗  ███████║██╔██╗ ██║${DEFAULT_COLOR}" "$width"
    box_line "${BOLD_GREEN}██╔═══╝ ██╔══██╗██╔══██║    ██║     ██║     ██╔══╝  ██╔══██║██║╚██╗██║${DEFAULT_COLOR}" "$width"
    box_line "${BOLD_GREEN}██║     ██║  ██║██║  ██║    ╚██████╗███████╗███████╗██║  ██║██║ ╚████║${DEFAULT_COLOR}" "$width"
    box_line "${BOLD_GREEN}╚═╝     ╚═╝  ╚═╝╚═╝  ╚═╝     ╚═════╝╚══════╝╚══════╝╚═╝  ╚═╝╚═╝  ╚═══╝${DEFAULT_COLOR}" "$width"
    box_mid "$width"
  else
    box_line "${BOLD_GREEN}PRA CLEAN${DEFAULT_COLOR}" "$width"
    box_mid "$width"
  fi
  box_line "$(center_line "${BOLD_WHITE}PRA CLEAN UTILITY${DEFAULT_COLOR}" "$width")" "$width"
  box_line "$(center_line "${CYAN}${subtitle}${DEFAULT_COLOR}" "$width")" "$width"
  box_line "$(center_line "$status_line" "$width")" "$width"
  box_bottom "$width"
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
  local conf=/etc/systemd/journald.conf current_use current_file max_use max_file vacuum_time vacuum_size backup
  print_section "Konfigurasi & Vacuum Journald"

  current_use=$(grep -Po '^SystemMaxUse=\K.*' "$conf" 2>/dev/null || echo "Tidak diatur")
  current_file=$(grep -Po '^SystemMaxFileSize=\K.*' "$conf" 2>/dev/null || echo "Tidak diatur")
  echo -e "  ${CYAN}Saat ini: SystemMaxUse=${BOLD_YELLOW}${current_use}${DEFAULT_COLOR}, SystemMaxFileSize=${BOLD_YELLOW}${current_file}${DEFAULT_COLOR}"

  if confirm "Ubah batas ukuran journald"; then
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
  local days
  print_section "Pembersihan /tmp"
  echo -e "  ${WARNING_PREFIX} Default aman: hapus item /tmp lebih tua dari N hari."
  days=$(prompt_default "Hapus item lebih tua dari berapa hari" "7")
  if ! is_valid_positive_int "$days"; then
    echo -e "  ${ERROR_PREFIX} Jumlah hari tidak valid."
    press_enter
    return
  fi

  echo -e "  ${WARNING_PREFIX} Opsi hapus semua /tmp berisiko untuk aplikasi aktif."
  if confirm "Paksa hapus SEMUA isi /tmp"; then
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
  local path
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
      confirm "Minta saran AI untuk path ini" && ask_ai_gemini "Beri saran aman mengosongkan ruang pada path: $path. Pisahkan file aman dihapus, perlu backup, dan jangan disentuh."
    else
      echo -e "  ${ERROR_PREFIX} Direktori tidak ditemukan: $path"
    fi
  fi
  press_enter
}

review_system_logs() {
  local log_file lines custom choice snippet
  prompt_menu_choice "Tinjau Log Sistem" "0-5" \
    "1|/var/log/syslog|Log sistem umum" \
    "2|/var/log/auth.log|Autentikasi dan sudo" \
    "3|/var/log/kern.log|Kernel dan driver" \
    "4|/var/log/dpkg.log|Riwayat paket APT" \
    "5|Path kustom|Baca file log manual" \
    "0|Kembali|Kembali ke menu sebelumnya"
  choice="$MENU_CHOICE"

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

  if confirm "Analisis AI untuk log ini"; then
    snippet=$(tail -n "$lines" "$log_file")
    ask_ai_gemini "Analisis potongan log berikut. Ringkas error/warning, kemungkinan sebab, dan aksi aman:\n\`\`\`\n${snippet}\n\`\`\`"
  fi
  press_enter
}

# ========== Menu ==========
submenu_app_cache_cleanup() {
  local choice
  while true; do
    prompt_menu_choice "Pembersihan Cache Aplikasi" "0-5" \
      "1|Bersihkan Cache NPM|Validasi lalu clean --force" \
      "2|Bersihkan Cache Pip3|Tampilkan info lalu purge" \
      "3|Bersihkan Cache Go|Clean build cache dan module cache" \
      "4|Bersihkan Cache Maven|Hapus ~/.m2/repository" \
      "5|Bersihkan Cache Gradle|Stop daemon lalu hapus caches" \
      "0|Kembali|Kembali ke menu utama"
    choice="$MENU_CHOICE"
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
    prompt_menu_choice "Utilitas Sistem" "0-2" \
      "1|Analisis Penggunaan Disk|Lihat filesystem dan direktori terbesar" \
      "2|Tinjau Log Sistem|Tail log penting + AI opsional" \
      "0|Kembali|Kembali ke menu utama"
    choice="$MENU_CHOICE"
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
  prompt_menu_choice "Menu Utama" "0-9,13" \
    "1|Bersihkan Cache APT|autoclean, clean, autoremove" \
    "2|Hapus Paket Tertentu|Validasi paket + AI opsional" \
    "3|Bersihkan Log /var/log|Truncate log aktif, hapus arsip" \
    "4|Konfigurasi Journald|Atur limit dan vacuum log" \
    "5|Hapus File /tmp|Default aman berdasarkan umur file" \
    "6|Bersihkan Cache User|Cleanup ~/.cache berdasarkan umur" \
    "7|Cache Aplikasi|NPM, Pip3, Go, Maven, Gradle" \
    "8|Docker Bertahap|Prune dengan konfirmasi per aksi" \
    "9|Utilitas Sistem|Analisis disk dan tinjau log" \
    "13|Jalankan Semua|Pembersihan utama berurutan" \
    "0|Keluar|Tutup PRA CLEAN"
}

main() {
  local choice
  parse_args "$@"
  check_sudo
  show_loading_animation
  check_ai_dependencies

  while true; do
    show_main_menu
    choice="$MENU_CHOICE"
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
