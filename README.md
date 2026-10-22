# git-found

[![CI](https://github.com/advaith334/git-found/actions/workflows/ci.yml/badge.svg)](https://github.com/advaith334/git-found/actions/workflows/ci.yml)
[![License: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)

A Git credential helper for people with more than one GitHub account. It checks which of your accounts can reach a repo and gives Git that account's token.

If you have a personal and a work account signed in to the GitHub CLI, you've probably seen this on a repo you definitely have access to:

```console
$ git clone https://github.com/mycompany/backend.git
remote: Repository not found.
fatal: repository 'https://github.com/mycompany/backend.git/' not found
```

Git sent the token for whichever account is active in `gh`, and that account can't see the repo. git-found makes Git use the account that can.

![gh is signed in to sam and sam-work, cloning a work repo fails, then works after git-found setup](demo/demo.gif)

<sub>The demo uses made-up accounts. git-found is the real script; `gh` and GitHub are stand-ins (see [demo/](demo/)).</sub>

## Install

Sign in to the GitHub CLI with each of your accounts first:

```bash
gh auth login   # once per account
```

Then:

```bash
brew install advaith334/tap/git-found
git-credential-found setup
```

`setup` points Git at git-found for every host you're signed in to with `gh` (usually just github.com).

<details>
<summary>Without Homebrew</summary>

```bash
curl -fsSL https://raw.githubusercontent.com/advaith334/git-found/main/install.sh | sh
```

This puts `git-credential-found` in `~/.local/bin` and runs `setup`.

Or copy the script yourself:

```bash
curl -fsSL https://raw.githubusercontent.com/advaith334/git-found/main/git-credential-found -o ~/.local/bin/git-credential-found
chmod +x ~/.local/bin/git-credential-found
git-credential-found setup
```

`setup` adds this to `~/.gitconfig`:

```ini
[credential "https://github.com"]
    helper =
    helper = /Users/you/.local/bin/git-credential-found
    useHttpPath = true
```

It writes the full path so GUI apps like GitHub Desktop and IntelliJ can find it.

</details>

## How it picks an account

When Git asks for a password, git-found goes through these in order:

1. The account you pinned for the repo, if any.
2. The account it picked for that repo in the last 24 hours.
3. The account whose name matches the repo owner (`sam-work/tool` tries `sam-work` first).
4. Otherwise it asks the GitHub API which of your accounts can see the repo, and prefers one that can push.

If none of them can see it, you get a clear message instead of a bare 404:

```console
git-found: none of your gh accounts on github.com (sam, sam-work) can see mycompany/secret.
git-found: check the URL, or add an account that has access with: gh auth login --hostname github.com
```

If the right account is blocked by the org's single sign-on, it tells you and prints the link to approve the token:

```console
git-found: sam-work can reach mycompany/backend, but its token isn't approved for the org's single sign-on.
git-found: approve it here, then try again: https://github.com/orgs/mycompany/sso?authorization_request=...
```

### Why Git doesn't handle this already

GitHub answers 404 rather than 401 when you're signed in but your account can't see a private repo. Git only retries with other credentials after a 401, so it never gets to your second account. The GitHub CLI's own helper only ever returns the active account's token ([cli/cli#326](https://github.com/cli/cli/issues/326) has been open since 2020).

## Commands

| Command | What it does |
|---|---|
| `git-credential-found setup [host...]` | Point Git at git-found (default: every host `gh` is signed in to) |
| `git-credential-found which [url]` | Show which account it would use for a repo |
| `git-credential-found doctor [url]` | Check why a repo still fails |
| `git-credential-found forget [url]` | Clear the remembered account for one repo, or all of them |
| `git-credential-found uninstall [host...]` | Remove git-found from your Git config |

A URL can be `owner/repo`, an HTTPS URL or an SSH URL. Without one, `which` and `doctor` use the current repo's `origin`.

### doctor

```console
$ git-credential-found doctor
git-found 0.2.1 doctor: mycompany/backend on github.com

Remote URL
  ✗ git@github.com:mycompany/backend.git uses SSH, and Git only asks credential helpers for HTTPS logins
    fix: git remote set-url origin https://github.com/mycompany/backend.git

Accounts on github.com
    · sam can't see this repo
  ✓ sam-work can push

Git config
  ✓ useHttpPath is on, so git-found can see which repo Git wants
  ✓ Git asks git-found, which picks sam-work (push)

1 problem(s) found.
```

It looks at the remote URL (SSH, or a token stuck in it), what each account can do, expired logins, single sign-on, your pin, and whether some other credential helper answers before git-found.

### Pinning

If two of your accounts can reach a repo and you want a specific one, set it inside the repo:

```bash
git config found.account sam-work
```

The pin only applies to that repo's own remotes, so cloning something else from inside it isn't affected. A username in the URL (`https://sam@github.com/...`) overrides everything.

### Debug output

```console
$ GIT_FOUND_DEBUG=1 git fetch
git-found: mycompany/backend as sam: none
git-found: mycompany/backend as sam-work: push
```

## Other ways to deal with this

| | Picks per repo automatically | No per-org config | No extra SSH keys |
|---|---|---|---|
| git-found | yes | yes | yes |
| `gh auth switch` | no, you switch by hand, for everything | yes | yes |
| `includeIf` with a helper per org | yes | no | yes |
| SSH host aliases | yes | no, every remote needs rewriting | no |
| Git Credential Manager | no, it asks you to pick | no | yes |

## FAQ

**Where do the tokens live?**
In the GitHub CLI's keyring, same as before. git-found reads one when Git needs it and never writes tokens anywhere. They're passed through environment variables and pipes, not command-line arguments. The only file it writes is `~/.cache/git-found/accounts`, which maps repos to account names.

**GitHub Enterprise?**
Yes. Run `gh auth login --hostname your.ghe.host`, then `git-credential-found setup`.

**SSH remotes?**
No. Credential helpers only run for HTTPS. Switch with `git remote set-url origin https://github.com/owner/repo.git`; `doctor` will point this out.

**It picked the wrong account.**
Pin the one you want with `git config found.account <login>`, or run `git-credential-found forget owner/repo` so it checks again.

**Can it pick the account for `gh pr create`, or fix my commit email?**
No. git-found only handles Git's HTTPS logins, and it's going to stay that way.

**How do I remove it?**
`git-credential-found uninstall`, then `gh auth setup-git` to go back to the GitHub CLI's helper.

**Requirements**
Bash (the macOS 3.2 one is fine), Git and the GitHub CLI. Tested on macOS and Ubuntu.

## Contributing

Issues and PRs welcome. `test/run.sh` runs the tests against a stand-in `gh`, so you don't need network access or GitHub accounts.

## License

[MIT](LICENSE)
