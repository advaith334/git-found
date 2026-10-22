# git-found

**Stop `remote: Repository not found`.** git-found picks the right GitHub account for every repo, automatically.

```console
$ git push
remote: Repository not found.
fatal: repository 'https://github.com/acme-corp/api.git/' not found
```

The repo exists. You have access. Git just signed in with the **wrong account**: your personal one instead of your work one, or the other way around.

git-found fixes that. Keep all your accounts signed in to the GitHub CLI, and Git uses the one that can actually reach each repo. No `gh auth switch`, no SSH host aliases, no `includeIf` blocks per org.

```console
$ git-credential-found which acme-corp/api
acme-corp/api -> alice-work (push)
```

## Install

You need the [GitHub CLI](https://cli.github.com) (`gh`) with each of your accounts signed in:

```bash
gh auth login   # repeat for every account
```

Then install git-found:

```bash
curl -fsSL https://raw.githubusercontent.com/advaith334/git-found/main/install.sh | sh
```

That puts `git-credential-found` in `~/.local/bin` and tells Git to use it for every host you're signed in to with `gh` (usually just `github.com`).

<details>
<summary>Install by hand instead</summary>

```bash
curl -fsSL https://raw.githubusercontent.com/advaith334/git-found/main/git-credential-found -o ~/.local/bin/git-credential-found
chmod +x ~/.local/bin/git-credential-found
git-credential-found setup
```

`setup` adds this to your `~/.gitconfig`:

```ini
[credential "https://github.com"]
    helper =
    helper = /Users/you/.local/bin/git-credential-found
    useHttpPath = true
```

It uses the full path so GUI apps like GitHub Desktop and IntelliJ find it too.

</details>

## How it works

When Git needs a password for a repo, git-found:

1. **Uses the account you pinned** for that repo, if you pinned one (see below).
2. **Uses your remembered choice** for that repo, if there is one (kept for a day).
3. **Tries the account named like the repo owner** first: `alice-work/tool` tries `alice-work`.
4. **Asks the GitHub API** which of your accounts can see the repo, preferring one that can push.
5. **Hands Git that account's token** and remembers the choice.

If none of your accounts can see the repo, it tells you so instead of leaving you with a vague 404:

```console
git-found: none of your gh accounts on github.com (alice, alice-work) can see acme-corp/secret.
git-found: check the URL, or add an account that has access with: gh auth login --hostname github.com
```

If the right account is blocked by the org's single sign-on (SSO), it says that too, with the link to approve the token:

```console
git-found: alice-work can reach acme-corp/api, but its token isn't approved for the org's single sign-on.
git-found: approve it here, then try again: https://github.com/orgs/acme-corp/sso?authorization_request=...
```

### Why Git can't do this on its own

GitHub returns **404, not 401**, when you're signed in but your account can't see a private repo. Git only throws away a password and asks again after a 401, so it never tries your other accounts. And the GitHub CLI's helper always returns the token of whichever account is active ([cli/cli#326](https://github.com/cli/cli/issues/326), open since 2020).

## Commands

| Command | What it does |
|---|---|
| `git-credential-found setup [host...]` | Make Git use git-found (default: every host `gh` is signed in to) |
| `git-credential-found which [url]` | Show which account git-found picks for a repo |
| `git-credential-found doctor [url]` | Explain why a repo still fails, with a fix for each problem |
| `git-credential-found forget [url]` | Forget the remembered account for one repo, or all |
| `git-credential-found uninstall [host...]` | Remove git-found from your Git config |

URLs can be `owner/repo`, an HTTPS URL or an SSH URL. Without one, `which` and `doctor` check the current repo's `origin`.

### Still failing? Run `doctor`

```console
$ git-credential-found doctor
git-found 0.2.0 doctor: acme-corp/api on github.com

Remote URL
  ✗ git@github.com:acme-corp/api.git uses SSH, and Git only asks credential helpers for HTTPS logins
    fix: git remote set-url origin https://github.com/acme-corp/api.git

Accounts on github.com
    · alice can't see this repo
  ✓ alice-work can push

Git config
  ✓ useHttpPath is on, so git-found can see which repo Git wants
  ✓ Git asks git-found, which picks alice-work (push)

1 problem(s) found.
```

It checks the remote URL (SSH, or a token baked into it), each account's access, expired logins, SSO approval, your pin, and whether another credential helper answers before git-found.

### Pin a repo to one account

If you can reach a repo from two accounts and want a specific one, pin it from inside the repo:

```bash
git config found.account alice-work
```

The pin only applies to that repo's own remotes, so cloning something else from inside it isn't affected. A username in the URL (`https://alice@github.com/...`) also works and wins over everything.

Set `GIT_FOUND_DEBUG=1` to see every decision:

```console
$ GIT_FOUND_DEBUG=1 git fetch
git-found: acme-corp/api as alice: none
git-found: acme-corp/api as alice-work: push
```

## Compared to the usual fixes

| | Works per repo, automatically | No config per org | No SSH keys to manage |
|---|:-:|:-:|:-:|
| **git-found** | ✅ | ✅ | ✅ |
| `gh auth switch` | ❌ manual, global | ✅ | ✅ |
| `includeIf` + per-org helper | ✅ | ❌ | ✅ |
| SSH host aliases | ✅ | ❌ rewrite every remote | ❌ |
| Git Credential Manager | ❌ asks you to pick | ❌ | ✅ |

## FAQ

**Is it safe?**
git-found never stores tokens. They stay in the GitHub CLI's keyring, and git-found asks for them only when Git needs one. Tokens are passed through environment variables and pipes, never as command-line arguments. The only thing it writes to disk is which account goes with which repo, in `~/.cache/git-found/accounts`.

**Does it work with GitHub Enterprise?**
Yes. Sign in with `gh auth login --hostname your.ghe.host`, then run `git-credential-found setup`. It sets up every host `gh` knows about.

**Does it work with SSH remotes?**
No. git-found is a credential helper, and those only run for HTTPS. Switch a remote with `git remote set-url origin https://github.com/owner/repo.git`. `doctor` spots this for you.

**It picked the wrong account.**
Pin the one you want with `git config found.account <login>` inside the repo, or run `git-credential-found forget owner/repo` to make it check again.

**What about `gh pr create`, commit emails or SSH keys?**
Out of scope on purpose. git-found does one thing: makes Git's HTTPS logins use the right account. It never runs `gh` commands for you or changes your commits.

**How do I remove it?**
Run `git-credential-found uninstall`, then `gh auth setup-git` to go back to the GitHub CLI's own helper.

**What does it need?**
Bash (macOS's built-in 3.2 is fine), Git and the GitHub CLI.

## Contributing

Issues and pull requests are welcome. If you've lost an afternoon to `Repository not found`, a ⭐ helps other people find this.

## License

[MIT](LICENSE)
