# Security

Git Account Router never reads or stores GitHub access tokens. Authentication is delegated to the official GitHub CLI, which normally stores credentials in the macOS Keychain.

Project routing changes only these local resources:

- the selected repository's `origin` URL and `git-account-router.*` local Git config keys;
- a dedicated Ed25519 key pair under `~/.ssh/`;
- a clearly marked host block in `~/.ssh/config`;
- the public half of that key in the selected GitHub account.

Report vulnerabilities privately through GitHub's **Security → Report a vulnerability** flow. Do not include tokens, private keys, or private repository contents in a report.
