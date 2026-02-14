#!/bin/bash
# Dotfiles installer — curl-safe, self-contained, styled.
# Usage: bash <(curl -fsSL dotfiles.salvarecuero.dev/install.sh)

set -euo pipefail

# ── Inline styling (TTY-aware) ────────────────────────────────────────────

if [ -t 1 ]; then
    _C_RESET='\033[0m'  _C_BOLD='\033[1m'  _C_DIM='\033[2m'
    _C_GREEN='\033[32m' _C_RED='\033[31m'   _C_CYAN='\033[36m'
    _C_WHITE='\033[97m' _C_MAGENTA='\033[35m' _C_BLUE='\033[34m'
else
    _C_RESET='' _C_BOLD='' _C_DIM='' _C_GREEN='' _C_RED=''
    _C_CYAN='' _C_WHITE='' _C_MAGENTA='' _C_BLUE=''
fi

log_info()  { printf "${_C_BLUE}  ▸${_C_RESET} %s\n" "$1"; }
log_ok()    { printf "${_C_GREEN}  ✓${_C_RESET} %s\n" "$1"; }
log_error() { printf "${_C_RED}  ✗${_C_RESET} %s\n" "$1"; }

banner() {
    local title="$1" subtitle="${2:-}"
    local width=${COLUMNS:-$(tput cols 2>/dev/null || echo 50)}
    (( width > 60 )) && width=60
    local inner=$(( width - 4 ))

    local top="┌$(printf '─%.0s' $(seq 1 $(( width - 2 ))))┐"
    local bot="└$(printf '─%.0s' $(seq 1 $(( width - 2 ))))┘"

    local pt=$(( (inner - ${#title}) / 2 ))
    (( pt < 0 )) && pt=0

    printf "\n${_C_MAGENTA}"
    printf "%s\n" "$top"
    printf "│${_C_RESET}${_C_BOLD}${_C_WHITE}%*s%-*s${_C_RESET}${_C_MAGENTA}│\n" \
        $(( pt + ${#title} )) "$title" $(( inner - pt - ${#title} )) ""
    if [ -n "$subtitle" ]; then
        local ps=$(( (inner - ${#subtitle}) / 2 ))
        (( ps < 0 )) && ps=0
        printf "│${_C_RESET}${_C_DIM}%*s%-*s${_C_RESET}${_C_MAGENTA}│\n" \
            $(( ps + ${#subtitle} )) "$subtitle" $(( inner - ps - ${#subtitle} )) ""
    fi
    printf "%s\n" "$bot"
    printf "${_C_RESET}\n"
}

# ── Main ──────────────────────────────────────────────────────────────────

REPO="salvarecuero/dotfiles"

banner "Salva's Dotfiles" "dotfiles.salvarecuero.dev"

# Prompt for token (read from /dev/tty so curl|bash works)
printf "${_C_DIM}    Create one at: https://github.com/settings/tokens${_C_RESET}\n"
printf "${_C_DIM}    Needs the 'repo' scope for private repos${_C_RESET}\n\n"
printf "${_C_BOLD}${_C_GREEN}  ? ${_C_RESET}${_C_BOLD}GitHub access token${_C_RESET}: "
if ! read -rs GITHUB_TOKEN < /dev/tty 2>/dev/null; then
    echo ""
    log_error "Cannot read from terminal — run with: bash <(curl -fsSL URL)"
    exit 1
fi
if [ -n "$GITHUB_TOKEN" ]; then
    printf "%s\n" "$(printf '•%.0s' $(seq 1 ${#GITHUB_TOKEN}))"
else
    echo ""
    log_error "No token provided — aborting"
    exit 1
fi

# Check dependencies
for cmd in curl git; do
    if ! command -v "$cmd" &>/dev/null; then
        log_error "$cmd is required but not installed"
        exit 1
    fi
done

# Install yadm if not present
if ! command -v yadm &>/dev/null; then
    log_info "Installing yadm..."
    if sudo -n true 2>/dev/null; then
        sudo curl -fLo /usr/local/bin/yadm \
            https://github.com/yadm-dev/yadm/raw/master/yadm
        sudo chmod a+x /usr/local/bin/yadm
        log_ok "yadm installed"
    else
        log_error "yadm is not installed and sudo requires a password"
        log_info "Install manually: sudo curl -fLo /usr/local/bin/yadm https://github.com/yadm-dev/yadm/raw/master/yadm && sudo chmod a+x /usr/local/bin/yadm"
        exit 1
    fi
else
    log_ok "yadm already installed"
fi

# Clone dotfiles
log_info "Cloning dotfiles..."
CLONE_URL="https://${GITHUB_TOKEN}@github.com/${REPO}.git"

if ! GITHUB_TOKEN="$GITHUB_TOKEN" yadm clone "$CLONE_URL" 2>&1; then
    log_error "Clone failed — check your token and try again"
    exit 1
fi
log_ok "Dotfiles cloned"

# Run bootstrap
log_info "Running bootstrap..."
if ! GITHUB_TOKEN="$GITHUB_TOKEN" yadm bootstrap; then
    log_error "Bootstrap failed — see output above"
    exit 1
fi
