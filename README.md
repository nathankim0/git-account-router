<p align="center">
  <img src="assets/readme-hero.png" alt="Git Account Router routes projects to separate developer accounts" width="100%">
</p>

<h1 align="center">Git Account Router</h1>

<p align="center">
  A native macOS app for assigning the right GitHub identity to every local project.
</p>

## Why

Using personal and work GitHub accounts on one Mac is easy until a push uses the wrong identity. `gh auth switch` changes a global CLI account, while repositories often need stable, project-specific credentials.

Git Account Router gives each selected account a dedicated SSH key and host alias, then rewrites only that project's `origin`. Switching the globally active GitHub CLI account no longer changes which account pushes that repository.

## Download

Download the latest DMG from [GitHub Releases](https://github.com/nathankim0/git-account-router/releases/latest), open it, and drag **Git Account Router** to **Applications**.

The first public build is ad-hoc signed rather than Apple-notarized. On first launch, Control-click the app and choose **Open** if macOS shows a security warning.

Requirements:

- macOS 14 or newer
- Apple Silicon (M1 or newer) for the downloadable build
- Git
- [GitHub CLI](https://cli.github.com/) (`brew install gh`)

## Features

- Register any existing Git repository from any folder.
- Register a new folder and initialize it as a Git repository only after confirmation.
- See the account, branch, origin, and routing state for every project.
- See the selected project's GitHub account in the macOS menu bar and switch projects there.
- Optionally start the app automatically when you log in to macOS.
- Keep multiple GitHub CLI accounts authenticated at the same time.
- Start GitHub's device authentication flow with the one-time code copied to the clipboard.
- Route a repository through a dedicated Ed25519 key and SSH host alias.
- Preserve and restore the original `origin` URL.
- Install the bundled `git-account-status` terminal helper.
- Never read or store GitHub access tokens.

## Onboarding

The first-run flow walks through four steps:

1. Understand project-specific routing.
2. Verify Git and GitHub CLI.
3. Review authenticated accounts or start device authentication.
4. Register the first project, including a safe new-repository flow.

To add another account later, click the person-plus button. A Terminal window opens with `gh auth login --web --clipboard`; GitHub displays a one-time device code and asks which account should approve it. Return to the app and refresh after approval.

## How routing works

For an account such as `octocat`, the app creates:

```text
~/.ssh/id_ed25519_git_account_router_octocat
Host github-gar-octocat
  HostName github.com
  User git
  IdentityFile ~/.ssh/id_ed25519_git_account_router_octocat
  IdentitiesOnly yes
```

It then converts the selected project's origin to:

```text
git@github-gar-octocat:owner/repository.git
```

The original remote is kept in local repository config and can be restored from the app. Source files, commits, and branches are not modified.

## Codex status

Current Codex releases expose only fixed status-line fields; they do not accept a custom command or a `git-account` field. This app therefore ships the closest safe integration without replacing the official Codex binary:

```sh
git-account-status
# GitHub @octocat · main · git@github-gar-octocat:owner/repository.git
```

Install it from the app's terminal button. The core account detector is kept independent so it can be wired into Codex as soon as an official custom status field exists.

## Build from source

```sh
git clone https://github.com/nathankim0/git-account-router.git
cd git-account-router
./scripts/check.sh
./scripts/create-dmg.sh 0.1.0
```

The app is built with Swift Package Manager and AppKit, with no third-party runtime dependencies.

## Privacy and safety

- Authentication is handled by the official GitHub CLI and macOS Keychain.
- Only public SSH keys are uploaded.
- SSH config edits are isolated inside marked, account-specific blocks.
- A malformed managed block stops the operation instead of rewriting the file.
- Every project change requires an explicit account choice and confirmation.

See [SECURITY.md](SECURITY.md) for the full boundary.

## License

[MIT](LICENSE)
