#!/usr/bin/env bash
# Tests for git-credential-found. They use a stand-in gh (test/stub/gh), so
# they need no network and no GitHub accounts. Run: test/run.sh

set -u

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PASS=0
FAIL=0
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

# Each test gets a fresh, isolated home: its own gh accounts, Git config and cache.
fresh() {
  TMP="$(mktemp -d "$WORK/t.XXXXXX")"
  mkdir -p "$TMP/bin" "$TMP/gh"
  cp "$ROOT/git-credential-found" "$ROOT/test/stub/gh" "$TMP/bin/"
  chmod +x "$TMP/bin/"*
  F="$TMP/bin/git-credential-found"
  export PATH="$TMP/bin:$BASE_PATH" GH_CONFIG_DIR="$TMP/gh" XDG_CACHE_HOME="$TMP/cache" \
    GIT_CONFIG_GLOBAL="$TMP/gitconfig" GIT_CONFIG_NOSYSTEM=1 GIT_TERMINAL_PROMPT=0
  unset GIT_FOUND_DEBUG STUB_ACCESS
  printf '[user]\n\tname = test\n\temail = test@example.com\n' > "$GIT_CONFIG_GLOBAL"
  cat > "$GH_CONFIG_DIR/hosts.yml" <<'EOF'
github.com:
    git_protocol: https
    users:
        alice:
        alice-work:
    user: alice
EOF
}

check() { # name expected actual
  if [ "$2" = "$3" ]; then
    PASS=$((PASS + 1)); echo "ok   $1"
  else
    FAIL=$((FAIL + 1)); echo "FAIL $1"; echo "     expected: $2"; echo "     actual:   $3"
  fi
}

contains() { # name needle haystack
  case "$3" in
    *"$2"*) PASS=$((PASS + 1)); echo "ok   $1" ;;
    *) FAIL=$((FAIL + 1)); echo "FAIL $1"; echo "     expected to contain: $2"; echo "     actual: $3" ;;
  esac
}

get_user() { # repo [extra credential lines]
  printf 'protocol=https\nhost=github.com\npath=%s.git\n%s\n' "$1" "${2:-}" | "$F" get 2>/dev/null \
    | sed -n 's/^username=//p'
}

BASE_PATH="$PATH"

fresh
check "version" "git-found $(sed -n 's/^VERSION="\(.*\)"/\1/p' "$ROOT/git-credential-found")" "$("$F" version)"

fresh
export STUB_ACCESS="alice-work:acme/api:push"
check "picks the account that can see the repo" "acme/api -> alice-work (push)" "$("$F" which acme/api)"
check "remembers the choice" "acme/api -> alice-work (cached)" "$("$F" which acme/api)"
"$F" forget acme/api >/dev/null
check "forget makes it check again" "acme/api -> alice-work (push)" "$("$F" which acme/api)"

for url in acme/api https://github.com/acme/api.git https://github.com/acme/api/tree/main \
  git@github.com:acme/api.git ssh://git@github.com/acme/api.git https://x-access-token:secret@github.com/acme/api.git; do
  check "reads $url" "acme/api" "$("$F" which "$url" | sed 's/ ->.*//')"
done

fresh
export STUB_ACCESS="alice:acme/api:pull alice-work:acme/api:push"
check "prefers push over pull" "acme/api -> alice-work (push)" "$("$F" which acme/api)"

fresh
export STUB_ACCESS="alice:acme/api:pull alice-work:acme/api:pull"
check "falls back to read access" "acme/api -> alice (pull)" "$("$F" which acme/api)"

fresh
export STUB_ACCESS="alice:alice-work/tool:push alice-work:alice-work/tool:push"
check "tries the owner's account first" "alice-work/tool -> alice-work (push)" "$("$F" which alice-work/tool)"

fresh
out=$("$F" which acme/secret 2>&1)
contains "says when no account can see the repo" "none of your gh accounts on github.com" "$out"
contains "falls back to the active account" "acme/secret -> alice (fallback)" "$out"

fresh
export STUB_ACCESS="alice-work:acme/api:sso"
out=$("$F" which acme/api 2>&1)
contains "detects SSO" "acme/api -> alice-work (sso)" "$out"
contains "prints the SSO approval link" "https://github.com/orgs/acme/sso?authorization_request=TEST" "$out"
check "doesn't remember an SSO block" "acme/api -> alice-work (sso)" "$("$F" which acme/api 2>/dev/null)"

fresh
export STUB_ACCESS="alice-work:*:expired"
contains "flags an expired login" "the saved login for alice-work has expired" "$("$F" which acme/api 2>&1)"

fresh
export STUB_ACCESS="alice-work:acme/api:push"
check "credential get returns the right account" "alice-work" "$(get_user acme/api)"
check "credential get gives a token" "password=tok-alice-work" \
  "$(printf 'protocol=https\nhost=github.com\npath=acme/api.git\n\n' | "$F" get | grep '^password=')"
check "a username in the URL wins" "alice" "$(get_user acme/api username=alice)"
check "ignores other hosts" "" "$(printf 'protocol=https\nhost=gitlab.com\npath=a/b.git\n\n' | "$F" get)"
check "ignores plain http" "" "$(printf 'protocol=http\nhost=github.com\npath=a/b.git\n\n' | "$F" get)"
check "uses the active account without a path" "alice" \
  "$(printf 'protocol=https\nhost=github.com\n\n' | "$F" get | sed -n 's/^username=//p')"
printf 'protocol=https\nhost=github.com\npath=acme/api.git\n\n' | "$F" erase
check "erase forgets the account" "acme/api -> alice-work (push)" "$("$F" which acme/api)"

fresh
export STUB_ACCESS="alice:acme/api:push alice-work:acme/api:push"
git init -q "$TMP/repo" && git -C "$TMP/repo" remote add origin https://github.com/acme/api.git
git -C "$TMP/repo" config found.account alice-work
check "a pin picks the account" "acme/api -> alice-work (pinned)" "$(cd "$TMP/repo" && "$F" which)"
check "credential get honours the pin" "alice-work" "$(cd "$TMP/repo" && get_user acme/api)"
check "a pin only applies to the repo's own remotes" "alice" "$(cd "$TMP/repo" && get_user acme/other)"
git -C "$TMP/repo" config found.account nobody
contains "an unknown pin is ignored with a warning" "found.account is nobody" "$(cd "$TMP/repo" && "$F" which 2>&1)"

fresh
cat >> "$GH_CONFIG_DIR/hosts.yml" <<'EOF'
ghe.example.com:
    users:
        corp:
    user: corp
EOF
"$F" setup >/dev/null
check "setup covers every gh host" "credential.https://ghe.example.com.helper credential.https://github.com.helper" \
  "$(git config --global --get-regexp 'credential\..*\.helper$' | awk '$2 != "" { print $1 }' | sort | tr '\n' ' ' | sed 's/ $//')"
check "setup points Git at the helper's full path" "$F" "$(git config --global --get-all credential.https://github.com.helper | tail -n 1)"
check "setup turns on useHttpPath" "true" "$(git config --global credential.https://github.com.useHttpPath)"
"$F" uninstall >/dev/null
check "uninstall removes every host" "" "$(git config --global --get-regexp '^credential\.' || true)"

fresh
export STUB_ACCESS="alice-work:acme/api:push"
"$F" setup >/dev/null
out=$("$F" doctor https://github.com/acme/api.git); code=$?
check "doctor passes a healthy repo" "0" "$code"
contains "doctor confirms Git asks git-found" "Git asks git-found, which picks alice-work" "$out"
out=$("$F" doctor git@github.com:acme/api.git); code=$?
check "doctor fails an SSH remote" "1" "$code"
contains "doctor explains the SSH fix" "git remote set-url origin https://github.com/acme/api.git" "$out"
contains "doctor never prints a token from the URL" "set-url origin https://github.com/acme/api.git" \
  "$("$F" doctor https://u:secret@github.com/acme/api.git)"

fresh
printf '[credential "https://github.com"]\n\thelper =\n\thelper = !gh auth git-credential\n' >> "$GIT_CONFIG_GLOBAL"
export STUB_ACCESS="alice-work:acme/api:push"
out=$("$F" doctor acme/api)
contains "doctor spots another helper answering first" "another credential helper answers first: Git got alice" "$out"
contains "doctor spots useHttpPath off" "useHttpPath is off" "$out"

echo
echo "$PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
