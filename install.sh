#!/usr/bin/env sh
# Installs git-found: downloads git-credential-found and points Git at it.
# https://github.com/advaith334/git-found
set -e

REPO="advaith334/git-found"
REF="${GIT_FOUND_REF:-main}"
BIN_DIR="${GIT_FOUND_BIN_DIR:-$HOME/.local/bin}"
URL="https://raw.githubusercontent.com/$REPO/$REF/git-credential-found"

command -v gh >/dev/null 2>&1 || { echo "git-found needs the GitHub CLI (gh): https://cli.github.com" >&2; exit 1; }
command -v curl >/dev/null 2>&1 || { echo "git-found's installer needs curl" >&2; exit 1; }

mkdir -p "$BIN_DIR"
curl -fsSL "$URL" -o "$BIN_DIR/git-credential-found"
chmod +x "$BIN_DIR/git-credential-found"
echo "git-found: installed to $BIN_DIR/git-credential-found"

"$BIN_DIR/git-credential-found" setup

case ":$PATH:" in
  *":$BIN_DIR:"*) ;;
  *) echo "git-found: tip: add $BIN_DIR to your PATH to run git-credential-found which/forget directly" ;;
esac
