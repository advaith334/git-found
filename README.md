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

That puts `git-credential-found` in `~/.local/bin` and tells Git to use it for `github.com`.

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
    helper = found
    useHttpPath = true
```

</details>

## How it works

When Git needs a password for a repo, git-found:

1. **Uses your remembered choice** for that repo, if there is one (kept for a day).
2. **Tries the account named like the repo owner** first: `alice-work/tool` tries `alice-work`.
3. **Asks the GitHub API** which of your accounts can see the repo, preferring one that can push.
4. **Hands Git that account's token** and remembers the choice.

If none of your accounts can see the repo, it tells you so instead of leaving you with a vague 404:

```console
git-found: none of your gh accounts on github.com (alice, alice-work) can see acme-corp/secret.
git-found: check the URL, or add an account that has access with: gh auth login --hostname github.com
```

### Why Git can't do this on its own

GitHub returns **404, not 401**, when you're signed in but your account can't see a private repo. Git only throws away a password and asks again after a 401, so it never tries your other accounts. And the GitHub CLI's helper always returns the token of whichever account is active ([cli/cli#326](https://github.com/cli/cli/issues/326), open since 2020).

## Commands

| Command | What it does |
|---|---|
| `git-credential-found setup [host]` | Make Git use git-found for a host (default `github.com`) |
| `git-credential-found which <url>` | Show which account git-found picks for a repo |
| `git-credential-found forget [url]` | Forget the remembered account for one repo, or all |
| `git-credential-found uninstall [host]` | Remove git-found from your Git config |

`which` and `forget` accept `owner/repo`, an HTTPS URL or an SSH URL.

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
Yes. Sign in with `gh auth login --hostname your.ghe.host`, then run `git-credential-found setup your.ghe.host`.

**Does it work with SSH remotes?**
No. git-found is a credential helper, and those only run for HTTPS. Switch a remote with `git remote set-url origin https://github.com/owner/repo.git`.

**It picked the wrong account.**
Run `git-credential-found forget owner/repo`, or force an account for one remote with `https://alice-work@github.com/owner/repo.git`. A username in the URL always wins.

**How do I remove it?**
Run `git-credential-found uninstall`, then `gh auth setup-git` to go back to the GitHub CLI's own helper.

**What does it need?**
Bash (macOS's built-in 3.2 is fine), Git and the GitHub CLI.

## Contributing

Issues and pull requests are welcome. If you've lost an afternoon to `Repository not found`, a ⭐ helps other people find this.

## License

[MIT](LICENSE)
