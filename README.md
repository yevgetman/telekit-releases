# telekit Releases

Public binary release channel for **telekit**.

This repo ships compiled runtime artifacts and install metadata only. The source
code lives in the private `yevgetman/telekit` repo.

Current version: **0.16.0** for macOS Apple Silicon (`arm64`) and Intel
(`x86_64`).

Start here: **[`GETTING_STARTED.md`](GETTING_STARTED.md)**.

## What You Get

**telekit** is a live two-way Telegram channel for your AI assistant. Two
directions:

- **Outbound** — from any agent session or scheduled job, `telekit send "…"`
  pushes a message to your phone (guarded: it refuses without an explicit
  `--yes`).
- **Inbound** — an always-on bridge daemon turns *your* Telegram messages into
  real headless agent sessions on your Mac and replies with their answers. You
  text your bot; the full assistant answers, with per-thread conversation
  continuity. Photos and documents work too.

The bridge answers exactly one owner (you), uses long-polling (no webhook, no
open port), and runs in the background on macOS `launchd`.

This release installs a compiled, self-contained `telekit` command (it bundles
its own Python). It does not include:

- telekit source code
- a Telegram bot token (you create your own with @BotFather)
- Keychain state or any personal configuration
- the Claude Code / Codex CLI the bridge drives

## Prerequisites

- macOS on Apple Silicon (`arm64`) or Intel (`x86_64`)
- The [Claude Code](https://claude.ai/code) CLI on `PATH` (`claude`) — the
  bridge animates its agent sessions through it (Codex, OpenCode, and SOV are
  supported as alternative harnesses, switchable in-chat with `/harness`)
- macOS `security` CLI, included with macOS
- A Telegram account and a bot token from
  [@BotFather](https://t.me/BotFather)

## Install

From the [latest release](../../releases/latest), download these files into one
folder:

- `install.sh`
- `VERSION`
- `SHA256SUMS`
- `telekit-runtime-0.16.0-macos-arm64.tar.gz` (Apple Silicon) **or**
  `telekit-runtime-0.16.0-macos-x86_64.tar.gz` (Intel)

Then run:

```sh
sh install.sh
```

The installer verifies the checksum, installs the compiled runtime under
`~/.telekit-runtime/<version>/`, and points `~/.local/bin/telekit` at the
compiled binary.

macOS Gatekeeper note: the binaries ship unsigned. If macOS quarantines the
downloaded runtime, clear it once:

```sh
xattr -dr com.apple.quarantine ~/.telekit-runtime
```

Verify:

```sh
telekit --version
```

Then follow **[`GETTING_STARTED.md`](GETTING_STARTED.md)** to store your bot
token, claim your chat, and start the bridge daemon.

## Upgrading

From v0.3.0 onward, upgrading is one command:

```sh
telekit self-update            # fetch + install the latest release
telekit self-update --check    # just see whether a newer version exists
```

It downloads the latest release, verifies the checksum, and runs the same
installer as a fresh install. (On a v0.2.0 install, which predates the
command, download the new release's files and re-run `sh install.sh` one last
time.)

Upgrades never touch your `~/.telekit` state or the Keychain — the owner
binding, node registry, conversation threads, and preferences all survive. If
the bridge daemon is running, the installer restarts it onto the new version
automatically.

To bounce the daemon without reinstalling, run:

```sh
telekit restart
```

## Safety Model

- The bridge answers **one owner only**: every message from anyone else is
  dropped before any agent session spawns, and only private 1:1 chats from the
  claimed owner are accepted.
- Optional passcode unlock can require `/unlock <passcode>` at the start of a
  Telegram session; the incoming unlock message is deleted on a best-effort
  basis.
- Outbound sends are guarded behind an explicit `--yes`.
- Secrets (the bot token, the owner binding) live in the macOS Keychain, never
  in files.
- Long-polling only — no webhook, no open inbound port.

## Support

This is a macOS-only runtime release. Report install/runtime issues to the
telekit maintainers with:

```sh
telekit --version
telekit status
```
