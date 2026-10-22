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
        sam:
        sam-work:
    user: sam
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

# A remote URL with a made-up token in it. It's assembled from variables so
# secret scanners don't mistake the test file for a leaked credential.
FAKE_USER="x-access-token"
FAKE_TOKEN="not-a-real-token"
TOKEN_URL="https://${FAKE_USER}:${FAKE_TOKEN}@github.com/mycompany/api.git"

fresh
check "version" "git-found $(sed -n 's/^VERSION="\(.*\)"/\1/p' "$ROOT/git-credential-found")" "$("$F" version)"

fresh
export STUB_ACCESS="sam-work:mycompany/api:push"
check "picks the account that can see the repo" "mycompany/api -> sam-work (push)" "$("$F" which mycompany/api)"
check "remembers the choice" "mycompany/api -> sam-work (cached)" "$("$F" which mycompany/api)"
"$F" forget mycompany/api >/dev/null
check "forget makes it check again" "mycompany/api -> sam-work (push)" "$("$F" which mycompany/api)"

for url in mycompany/api https://github.com/mycompany/api.git https://github.com/mycompany/api/tree/main \
  git@github.com:mycompany/api.git ssh://git@github.com/mycompany/api.git "$TOKEN_URL"; do
  check "reads ${url/$FAKE_TOKEN/***}" "mycompany/api" "$("$F" which "$url" | sed 's/ ->.*//')"
done

fresh
export STUB_ACCESS="sam:mycompany/api:pull sam-work:mycompany/api:push"
check "prefers push over pull" "mycompany/api -> sam-work (push)" "$("$F" which mycompany/api)"

fresh
export STUB_ACCESS="sam:mycompany/api:pull sam-work:mycompany/api:pull"
check "falls back to read access" "mycompany/api -> sam (pull)" "$("$F" which mycompany/api)"

fresh
export STUB_ACCESS="sam:sam-work/tool:push sam-work:sam-work/tool:push"
check "tries the owner's account first" "sam-work/tool -> sam-work (push)" "$("$F" which sam-work/tool)"

fresh
out=$("$F" which mycompany/secret 2>&1)
contains "says when no account can see the repo" "none of your gh accounts on github.com" "$out"
contains "falls back to the active account" "mycompany/secret -> sam (fallback)" "$out"

fresh
export STUB_ACCESS="sam-work:mycompany/api:sso"
out=$("$F" which mycompany/api 2>&1)
contains "detects SSO" "mycompany/api -> sam-work (sso)" "$out"
contains "prints the SSO approval link" "https://github.com/orgs/mycompany/sso?authorization_request=TEST" "$out"
check "doesn't remember an SSO block" "mycompany/api -> sam-work (sso)" "$("$F" which mycompany/api 2>/dev/null)"

fresh
export STUB_ACCESS="sam-work:*:expired"
contains "flags an expired login" "the saved login for sam-work has expired" "$("$F" which mycompany/api 2>&1)"

fresh
export STUB_ACCESS="sam-work:mycompany/api:push"
check "credential get returns the right account" "sam-work" "$(get_user mycompany/api)"
check "credential get gives a token" "password=tok-sam-work" \
  "$(printf 'protocol=https\nhost=github.com\npath=mycompany/api.git\n\n' | "$F" get | grep '^password=')"
check "a username in the URL wins" "sam" "$(get_user mycompany/api username=sam)"
check "ignores other hosts" "" "$(printf 'protocol=https\nhost=gitlab.com\npath=a/b.git\n\n' | "$F" get)"
check "ignores plain http" "" "$(printf 'protocol=http\nhost=github.com\npath=a/b.git\n\n' | "$F" get)"
check "uses the active account without a path" "sam" \
  "$(printf 'protocol=https\nhost=github.com\n\n' | "$F" get | sed -n 's/^username=//p')"
printf 'protocol=https\nhost=github.com\npath=mycompany/api.git\n\n' | "$F" erase
check "erase forgets the account" "mycompany/api -> sam-work (push)" "$("$F" which mycompany/api)"

fresh
export STUB_ACCESS="sam:mycompany/api:push sam-work:mycompany/api:push"
git init -q "$TMP/repo" && git -C "$TMP/repo" remote add origin https://github.com/mycompany/api.git
git -C "$TMP/repo" config found.account sam-work
check "a pin picks the account" "mycompany/api -> sam-work (pinned)" "$(cd "$TMP/repo" && "$F" which)"
check "credential get honours the pin" "sam-work" "$(cd "$TMP/repo" && get_user mycompany/api)"
check "a pin only applies to the repo's own remotes" "sam" "$(cd "$TMP/repo" && get_user mycompany/other)"
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
export STUB_ACCESS="sam-work:mycompany/api:push"
"$F" setup >/dev/null
out=$("$F" doctor https://github.com/mycompany/api.git); code=$?
check "doctor passes a healthy repo" "0" "$code"
contains "doctor confirms Git asks git-found" "Git asks git-found, which picks sam-work" "$out"
out=$("$F" doctor git@github.com:mycompany/api.git); code=$?
check "doctor fails an SSH remote" "1" "$code"
contains "doctor explains the SSH fix" "git remote set-url origin https://github.com/mycompany/api.git" "$out"
out=$("$F" doctor "$TOKEN_URL")
contains "doctor gives a clean URL for a remote with a token" "set-url origin https://github.com/mycompany/api.git" "$out"
case "$out" in
  *"$FAKE_TOKEN"*) FAIL=$((FAIL + 1)); echo "FAIL doctor never prints a token from the URL" ;;
  *) PASS=$((PASS + 1)); echo "ok   doctor never prints a token from the URL" ;;
esac

fresh
printf '[credential "https://github.com"]\n\thelper =\n\thelper = !gh auth git-credential\n' >> "$GIT_CONFIG_GLOBAL"
export STUB_ACCESS="sam-work:mycompany/api:push"
out=$("$F" doctor mycompany/api)
contains "doctor spots another helper answering first" "another credential helper answers first: Git got sam" "$out"
contains "doctor spots useHttpPath off" "useHttpPath is off" "$out"

echo
echo "$PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
