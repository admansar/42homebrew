#!/bin/bash

set -e

BREW_VERSION="4.4.32"
BREW_DIR="$HOME/goinfre/homebrew"
CORE_DIR="$BREW_DIR/Library/Taps/homebrew/homebrew-core"
CASK_DIR="$BREW_DIR/Library/Taps/homebrew/homebrew-cask"
ZSHRC="$HOME/.zshrc"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
CYAN='\033[0;36m'
BOLD='\033[1m'
DIM='\033[2m'
RESET='\033[0m'

CHECK="${GREEN}✔${RESET}"
CROSS="${RED}✘${RESET}"
WARN="${YELLOW}⚠${RESET}"
ARROW="${CYAN}➜${RESET}"

clear_line() {
    printf '\r\033[K'
}

spinner() {
    pid="$1"
    message="$2"
    frames='|/-\'
    i=0

    while kill -0 "$pid" 2>/dev/null; do
        i=$(( (i + 1) % 4 ))
        frame="$(printf "%s" "$frames" | cut -c $((i + 1)))"
        printf "\r${CYAN}%s${RESET} %s" "$frame" "$message"
        sleep 0.12
    done

    wait "$pid"
    status=$?

    clear_line

    if [ "$status" -eq 0 ]; then
        printf "${CHECK} %s\n" "$message"
    else
        printf "${CROSS} %s\n" "$message"
        return "$status"
    fi
}

run_step() {
    message="$1"
    shift

    logfile="$(mktemp)"

    (
        "$@"
    ) >"$logfile" 2>&1 &

    pid=$!

    if ! spinner "$pid" "$message"; then
        echo
        printf "${RED}${BOLD}Command failed:${RESET}\n"
        cat "$logfile"
        rm -f "$logfile"
        exit 1
    fi

    rm -f "$logfile"
}

section() {
    echo
    printf "${BLUE}${BOLD}━━━ %s ━━━${RESET}\n" "$1"
}

info() {
    printf "${ARROW} %s\n" "$1"
}

success() {
    printf "${CHECK} %s\n" "$1"
}

warning() {
    printf "${WARN} %s\n" "$1"
}

error() {
    printf "${CROSS} %s\n" "$1"
}

banner() {
    printf "${CYAN}${BOLD}"
    cat <<'EOF'

╔══════════════════════════════════════════════╗
║                                              ║
║        42 Catalina Homebrew Installer        ║
║                                              ║
║                           by admansar        ║
║                                              ║
╚══════════════════════════════════════════════╝

EOF
    printf "${RESET}"
}

brew_legacy() {
    HOMEBREW_NO_AUTO_UPDATE=1 \
    HOMEBREW_NO_INSTALL_FROM_API=1 \
    "$BREW_DIR/bin/brew" "$@"
}

banner

MACOS_VERSION="$(sw_vers -productVersion)"
ARCH="$(uname -m)"

section "System"

printf "  ${DIM}User${RESET}          %s\n" "$USER"
printf "  ${DIM}macOS${RESET}         %s\n" "$MACOS_VERSION"
printf "  ${DIM}Architecture${RESET}  %s\n" "$ARCH"
printf "  ${DIM}Install path${RESET}  %s\n" "$BREW_DIR"

if [ "$ARCH" != "x86_64" ]; then
    error "This installer is intended for Intel x86_64 Macs."
    exit 1
fi

case "$MACOS_VERSION" in
    10.15*)
        success "macOS Catalina detected"
        ;;
    *)
        warning "This script was tested on macOS Catalina 10.15.x."
        printf "Continue anyway? [y/N] "
        read -r answer

        case "$answer" in
            y|Y|yes|YES)
                ;;
            *)
                exit 1
                ;;
        esac
        ;;
esac

section "Requirements"

if ! command -v git >/dev/null 2>&1; then
    error "git is missing."
    info "Xcode or Xcode Command Line Tools must already be installed."
    exit 1
fi

success "git found: $(command -v git)"

if ! command -v curl >/dev/null 2>&1; then
    error "curl is missing."
    exit 1
fi

success "curl found: $(command -v curl)"

if [ ! -d "$HOME/goinfre" ]; then
    error "~/goinfre does not exist."
    exit 1
fi

REAL_GOINFRE="$(cd "$HOME/goinfre" && pwd -P)"

success "goinfre found: $REAL_GOINFRE"

section "User environment cleanup"

if [ -d "$HOME/Library/Python" ]; then
    PYTHON_PERMS="$(
        stat -f '%Lp' "$HOME/Library/Python" 2>/dev/null || true
    )"

    case "$PYTHON_PERMS" in
        *7)
            chmod 755 "$HOME/Library/Python"
            success "Fixed ~/Library/Python permissions"
            ;;
        *)
            success "~/Library/Python permissions are safe"
            ;;
    esac
fi

if [ -f "$HOME/.npmrc" ]; then
    sed -i '' \
        '/^[[:space:]]*prefix[[:space:]]*=/d' \
        "$HOME/.npmrc"
fi

unset NPM_CONFIG_PREFIX
unset npm_config_prefix

for file in \
    "$HOME/.zshrc" \
    "$HOME/.zprofile" \
    "$HOME/.profile" \
    "$HOME/.bash_profile" \
    "$HOME/.bashrc"
do
    if [ -f "$file" ]; then
        sed -i '' \
            '/^[[:space:]]*export[[:space:]]*NPM_CONFIG_PREFIX=/d' \
            "$file"

        sed -i '' \
            '/^[[:space:]]*export[[:space:]]*npm_config_prefix=/d' \
            "$file"
    fi
done

if command -v npm >/dev/null 2>&1; then
    npm config delete prefix >/dev/null 2>&1 || true
    success "npm user prefix cleaned"
fi

if command -v nvm >/dev/null 2>&1 &&
   command -v node >/dev/null 2>&1; then

    NODE_VERSION="$(node -v 2>/dev/null || true)"

    if [ -n "$NODE_VERSION" ]; then
        nvm use \
            --delete-prefix \
            "$NODE_VERSION" \
            --silent \
            >/dev/null 2>&1 || true

        success "NVM prefix cleaned for $NODE_VERSION"
    fi
fi

section "Homebrew"

if [ -e "$BREW_DIR" ]; then
    info "Removing previous Homebrew installation..."
    rm -rf "$BREW_DIR"
fi

run_step \
    "Cloning Homebrew" \
    git clone \
    https://github.com/Homebrew/brew.git \
    "$BREW_DIR"

cd "$BREW_DIR"

run_step \
    "Fetching Homebrew tags" \
    git fetch --tags

run_step \
    "Pinning Homebrew to $BREW_VERSION" \
    git checkout \
    -B "catalina-$BREW_VERSION" \
    "$BREW_VERSION"

BREW_DATE="$(git show -s --format=%cI HEAD)"

success "Homebrew pinned to $BREW_VERSION"
info "Revision date: $BREW_DATE"

section "homebrew-core"

mkdir -p "$(dirname "$CORE_DIR")"

run_step \
    "Cloning homebrew-core" \
    git clone \
    https://github.com/Homebrew/homebrew-core.git \
    "$CORE_DIR"

CORE_REMOTE_BRANCH="$(
    git -C "$CORE_DIR" \
    symbolic-ref \
    --short \
    refs/remotes/origin/HEAD
)"

CORE_COMMIT="$(
    git -C "$CORE_DIR" \
    rev-list \
    -1 \
    --before="$BREW_DATE" \
    "$CORE_REMOTE_BRANCH"
)"

if [ -z "$CORE_COMMIT" ]; then
    error "Could not find a matching homebrew-core commit."
    exit 1
fi

run_step \
    "Pinning homebrew-core" \
    git -C "$CORE_DIR" checkout "$CORE_COMMIT"

success "homebrew-core frozen"
info "Core commit: $CORE_COMMIT"

section "homebrew-cask"

mkdir -p "$(dirname "$CASK_DIR")"

run_step \
    "Cloning homebrew-cask" \
    git clone \
    https://github.com/Homebrew/homebrew-cask.git \
    "$CASK_DIR"

CASK_REMOTE_BRANCH="$(
    git -C "$CASK_DIR" \
    symbolic-ref \
    --short \
    refs/remotes/origin/HEAD
)"

CASK_COMMIT="$(
    git -C "$CASK_DIR" \
    rev-list \
    -1 \
    --before="$BREW_DATE" \
    "$CASK_REMOTE_BRANCH"
)"

if [ -n "$CASK_COMMIT" ]; then
    run_step \
        "Pinning homebrew-cask" \
        git -C "$CASK_DIR" checkout "$CASK_COMMIT"

    success "homebrew-cask frozen"
    info "Cask commit: $CASK_COMMIT"
else
    warning "No matching historical homebrew-cask commit found."
fi

section "Shell configuration"

touch "$ZSHRC"

TMP_ZSHRC="$(mktemp)"

awk '
BEGIN {
    skip=0
}

$0 == "# >>> 42 CATALINA HOMEBREW >>>" {
    skip=1
    next
}

$0 == "# <<< 42 CATALINA HOMEBREW <<<" {
    skip=0
    next
}

skip == 0 {
    print
}
' "$ZSHRC" > "$TMP_ZSHRC"

mv "$TMP_ZSHRC" "$ZSHRC"

cat >> "$ZSHRC" <<'EOF'

# >>> 42 CATALINA HOMEBREW >>>

export HOMEBREW_PREFIX="$HOME/goinfre/homebrew"
export HOMEBREW_CELLAR="$HOME/goinfre/homebrew/Cellar"
export HOMEBREW_REPOSITORY="$HOME/goinfre/homebrew"

export PATH="$HOMEBREW_PREFIX/bin:$HOMEBREW_PREFIX/sbin:$PATH"

export MANPATH="$HOMEBREW_PREFIX/share/man:${MANPATH:-}"
export INFOPATH="$HOMEBREW_PREFIX/share/info:${INFOPATH:-}"

export HOMEBREW_NO_AUTO_UPDATE=1
export HOMEBREW_NO_INSTALL_FROM_API=1

brew() {
    HOMEBREW_NO_AUTO_UPDATE=1 \
    HOMEBREW_NO_INSTALL_FROM_API=1 \
    "$HOME/goinfre/homebrew/bin/brew" "$@"
}

# <<< 42 CATALINA HOMEBREW <<<
EOF

export HOMEBREW_PREFIX="$BREW_DIR"
export HOMEBREW_CELLAR="$BREW_DIR/Cellar"
export HOMEBREW_REPOSITORY="$BREW_DIR"

export PATH="$BREW_DIR/bin:$BREW_DIR/sbin:$PATH"

export MANPATH="$BREW_DIR/share/man:${MANPATH:-}"
export INFOPATH="$BREW_DIR/share/info:${INFOPATH:-}"

export HOMEBREW_NO_AUTO_UPDATE=1
export HOMEBREW_NO_INSTALL_FROM_API=1

brew() {
    HOMEBREW_NO_AUTO_UPDATE=1 \
    HOMEBREW_NO_INSTALL_FROM_API=1 \
    "$HOME/goinfre/homebrew/bin/brew" "$@"
}

hash -r

success "~/.zshrc configured"
success "Legacy brew wrapper installed"

section "Legacy protection"

if [ "$HOMEBREW_NO_AUTO_UPDATE" = "1" ]; then
    success "Homebrew automatic updates disabled"
else
    error "HOMEBREW_NO_AUTO_UPDATE is not active"
    exit 1
fi

if [ "$HOMEBREW_NO_INSTALL_FROM_API" = "1" ]; then
    success "Homebrew Formula API disabled"
else
    error "HOMEBREW_NO_INSTALL_FROM_API is not active"
    exit 1
fi

section "Verification"

success "brew: $BREW_DIR/bin/brew"
success "version: $(brew_legacy --version | head -1)"
success "prefix: $(brew_legacy --prefix)"
success "cellar: $(brew_legacy --cellar)"

CORE_INFO="$(
    git -C "$CORE_DIR" \
    log -1 \
    --format='%h %ci'
)"

success "core: $CORE_INFO"

if [ -d "$CASK_DIR/.git" ]; then
    CASK_INFO="$(
        git -C "$CASK_DIR" \
        log -1 \
        --format='%h %ci'
    )"

    success "cask: $CASK_INFO"
fi

section "Formula resolution"

TREE_PATH="$(
    brew_legacy formula-path tree 2>/dev/null || true
)"

if [ -n "$TREE_PATH" ]; then
    success "tree formula resolved"

    printf "  ${DIM}%s${RESET}\n" "$TREE_PATH"

    case "$TREE_PATH" in
        "$CORE_DIR"/*)
            success "tree uses frozen homebrew-core"
            ;;
        *)
            warning "tree did not resolve inside the frozen Core tap"
            ;;
    esac
else
    warning "Could not resolve the tree formula locally."
fi

section "Brew environment"

BREW_CONFIG="$(brew_legacy config 2>/dev/null || true)"

if printf '%s\n' "$BREW_CONFIG" |
    grep -q 'HOMEBREW_NO_INSTALL_FROM_API'; then

    success "NO_INSTALL_FROM_API visible to Homebrew"
else
    warning "NO_INSTALL_FROM_API not printed by brew config"
fi

if printf '%s\n' "$BREW_CONFIG" |
    grep -q 'HOMEBREW_NO_AUTO_UPDATE'; then

    success "NO_AUTO_UPDATE visible to Homebrew"
else
    warning "NO_AUTO_UPDATE not printed by brew config"
fi

section "Done"

printf "${GREEN}${BOLD}"

cat <<'EOF'

╔══════════════════════════════════════════════╗
║                                              ║
║         Homebrew installed successfully      ║
║                                              ║
╚══════════════════════════════════════════════╝

EOF

printf "${RESET}"

printf "  ${CYAN}Homebrew${RESET}  %s\n" "$BREW_DIR"
printf "  ${CYAN}Version${RESET}   %s\n" \
    "$(brew_legacy --version | head -1)"
printf "  ${CYAN}Cellar${RESET}    %s\n" \
    "$(brew_legacy --cellar)"

echo

warning "This Homebrew installation is intentionally frozen for Catalina."

echo
printf "${BOLD}Do not run:${RESET}\n"
printf "  ${RED}brew update${RESET}\n"

echo
printf "${BOLD}Enabled protections:${RESET}\n"
printf "  ${GREEN}HOMEBREW_NO_AUTO_UPDATE=1${RESET}\n"
printf "  ${GREEN}HOMEBREW_NO_INSTALL_FROM_API=1${RESET}\n"
printf "  ${GREEN}brew() legacy wrapper${RESET}\n"

echo
printf "${BOLD}Reload your shell:${RESET}\n"
printf "  ${CYAN}source ~/.zshrc${RESET}\n"

echo
printf "${BOLD}Verify the wrapper:${RESET}\n"
printf "  ${CYAN}type brew${RESET}\n"

echo
printf "${BOLD}Try it:${RESET}\n"
printf "  ${CYAN}brew install tree${RESET}\n"
printf "  ${CYAN}tree --version${RESET}\n"

echo
printf "${BOLD}Or:${RESET}\n"
printf "  ${CYAN}brew install lolcat${RESET}\n"

echo
