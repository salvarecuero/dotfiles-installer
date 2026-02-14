# dotfiles-installer

Landing page and installer script for [Salva's dotfiles](https://github.com/salvarecuero/dotfiles).

Hosted at [dotfiles.salvarecuero.dev](https://dotfiles.salvarecuero.dev) via GitHub Pages.

## What it does

The installer bootstraps a new machine with a single command:

```bash
bash <(curl -fsSL dotfiles.salvarecuero.dev/install.sh)
```

It will:

1. Prompt for a GitHub access token (masked input, reads from `/dev/tty`)
2. Install [yadm](https://yadm.io) if not present
3. Clone the private dotfiles repo
4. Run `yadm bootstrap` (installs zsh, nvm, direnv, Claude Code, etc.)

## Files

| File | Purpose |
|------|---------|
| `index.html` | Landing page with copy-to-clipboard install command |
| `install.sh` | Curl-safe bash installer |
| `CNAME` | GitHub Pages custom domain (`dotfiles.salvarecuero.dev`) |

## Requirements

The installer expects:

- `curl` and `git` available in PATH
- Passwordless `sudo` for installing yadm (or yadm already installed)
- A GitHub personal access token with `repo` scope

## Development

This is a static GitHub Pages site. Push to `main` to deploy.
