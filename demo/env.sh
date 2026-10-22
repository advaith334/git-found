# Sourced (hidden) by demo.tape: a throwaway home where gh is signed in as
# alice (active) and alice-work, and only alice-work can see acme-corp/api.
# git-found itself is the real script; gh and the network are stand-ins.

ROOT="$(pwd)"
DEMO="$(mktemp -d)"
mkdir -p "$DEMO/bin" "$DEMO/gh" "$DEMO/work"
cp "$ROOT/git-credential-found" "$ROOT/test/stub/gh" "$ROOT/demo/git" "$DEMO/bin/"
chmod +x "$DEMO/bin/"*

cat > "$DEMO/gh/hosts.yml" <<'EOF'
github.com:
    users:
        alice:
        alice-work:
    user: alice
EOF

# What `gh auth setup-git` leaves you with: always the active account.
printf '[credential "https://github.com"]\n\thelper =\n\thelper = !gh auth git-credential\n' > "$DEMO/gitconfig"

export REAL_GIT
REAL_GIT="$(command -v git)"
export PATH="$DEMO/bin:$PATH" GH_CONFIG_DIR="$DEMO/gh" XDG_CACHE_HOME="$DEMO/cache" \
  GIT_CONFIG_GLOBAL="$DEMO/gitconfig" GIT_CONFIG_NOSYSTEM=1 GIT_TERMINAL_PROMPT=0 \
  STUB_ACCESS="alice-work:acme-corp/api:push"
export PS1='\[\e[1;35m\]$\[\e[0m\] '
cd "$DEMO/work" || return
