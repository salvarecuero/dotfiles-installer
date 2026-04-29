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
log_warn()  { printf "${_C_BLUE}  !${_C_RESET} %s\n" "$1"; }
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

# Check dependencies
for cmd in curl git; do
    if ! command -v "$cmd" &>/dev/null; then
        log_error "$cmd is required but not installed"
        exit 1
    fi
done

# Auth detection: try SSH agent first (e.g. when reached via `ssh -A`),
# fall back to a personal access token.
USE_SSH=false
GITHUB_TOKEN=""

if [ -n "${SSH_AUTH_SOCK:-}" ] && command -v ssh &>/dev/null; then
    log_info "SSH agent detected — testing GitHub access..."
    _ssh_test=$(ssh -T -o BatchMode=yes -o ConnectTimeout=5 \
        -o StrictHostKeyChecking=accept-new git@github.com 2>&1 || true)
    if printf '%s' "$_ssh_test" | grep -q "successfully authenticated"; then
        USE_SSH=true
        log_ok "SSH access works — skipping token prompt"
    else
        log_warn "SSH agent can't auth to GitHub — falling back to token"
    fi
fi

if [ "$USE_SSH" = false ]; then
    # Prompt for token (read from /dev/tty so curl|bash works)
    printf "${_C_DIM}    Create one at: https://github.com/settings/tokens${_C_RESET}\n"
    printf "${_C_DIM}    Classic token: needs 'repo' scope${_C_RESET}\n"
    printf "${_C_DIM}    Fine-grained:  needs 'Contents: Read' for the dotfiles repo${_C_RESET}\n\n"
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
fi

# Install yadm if not present
if ! command -v yadm &>/dev/null; then
    log_info "Installing yadm (sudo may prompt for password)..."
    if sudo curl -fLo /usr/local/bin/yadm \
            https://github.com/yadm-dev/yadm/raw/master/yadm \
        && sudo chmod a+x /usr/local/bin/yadm; then
        log_ok "yadm installed"
    else
        log_error "yadm install failed"
        log_info "Install manually: sudo curl -fLo /usr/local/bin/yadm https://github.com/yadm-dev/yadm/raw/master/yadm && sudo chmod a+x /usr/local/bin/yadm"
        exit 1
    fi
else
    log_ok "yadm already installed"
fi

# Clone or pull dotfiles. Use SSH if available, else GIT_ASKPASS with the token
# (askpass keeps the token out of the process list and remote URL).
if [ "$USE_SSH" = true ]; then
    _clone_url="git@github.com:${REPO}.git"
    _auth_hint="SSH agent"
else
    _clone_url="https://github.com/${REPO}.git"
    _auth_hint="token"
    _askpass="$(mktemp)"
    trap 'rm -f "$_askpass"' EXIT
    cat > "$_askpass" << 'ASKPASS'
#!/bin/sh
case "$1" in
    Username*) echo "x-access-token" ;;
    *) echo "$GITHUB_TOKEN" ;;
esac
ASKPASS
    chmod +x "$_askpass"
    export GITHUB_TOKEN GIT_ASKPASS="$_askpass"
fi

if [ -d "$HOME/.local/share/yadm/repo.git" ]; then
    log_ok "Dotfiles already cloned"
    # Make sure the remote matches the auth method we're about to use,
    # otherwise pull will try the wrong credentials.
    _current_url=$(yadm remote get-url origin 2>/dev/null || echo "")
    if [ "$_current_url" != "$_clone_url" ]; then
        log_info "Switching remote to $_auth_hint URL..."
        yadm remote set-url origin "$_clone_url"
    fi
    log_info "Pulling latest changes..."
    if ! yadm pull 2>&1; then
        log_error "Pull failed — check your $_auth_hint and try again"
        exit 1
    fi
    log_ok "Dotfiles updated"
else
    log_info "Cloning dotfiles via $_auth_hint..."
    if ! yadm clone --no-bootstrap "$_clone_url" 2>&1; then
        log_error "Clone failed — check your $_auth_hint and try again"
        exit 1
    fi
    log_ok "Dotfiles cloned"
fi
[ -n "${_askpass:-}" ] && rm -f "$_askpass"

# Run bootstrap. GITHUB_TOKEN is only forwarded if we actually have one;
# bootstrap's container path will prompt for a token itself if needed.
log_info "Running bootstrap..."
if ! GITHUB_TOKEN="$GITHUB_TOKEN" yadm bootstrap; then
    log_error "Bootstrap failed — see output above"
    exit 1
fi
