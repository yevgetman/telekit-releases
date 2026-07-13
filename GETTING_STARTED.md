# Getting Started With telekit

This guide is for installing the compiled telekit runtime from the public
release channel. It does not require access to the private source repository.

telekit connects a Telegram bot you own to an AI coding-agent CLI on your Mac.
It does not create the Telegram bot for you, and it does not bundle the agent
CLI. Those are one-time setup steps below.

## 1. Verify The Agent CLI

The bridge answers your Telegram messages by running a real headless agent
session through the [Claude Code](https://claude.ai/code) CLI. Verify it is
available:

```sh
claude --version
```

If that command is missing, install Claude Code first, then return here. Codex,
OpenCode, and SOV are supported as alternative harnesses; you can switch from
inside the chat later with `/harness`.

## 2. Install The telekit Runtime

Download these files from the
[latest release](https://github.com/yevgetman/telekit-releases/releases/latest)
into one folder:

- `install.sh`
- `VERSION`
- `SHA256SUMS`
- `telekit-runtime-<version>-macos-arm64.tar.gz` (Apple Silicon) **or**
  `telekit-runtime-<version>-macos-x86_64.tar.gz` (Intel)

For example, with `curl` (Apple Silicon shown — swap the arch in the tarball name
for Intel, and set `VER` to the latest version shown on the release page):

```sh
VER=0.18.2
BASE=https://github.com/yevgetman/telekit-releases/releases/latest/download
curl -L -O "$BASE/install.sh" \
     -O "$BASE/VERSION" \
     -O "$BASE/SHA256SUMS" \
     -O "$BASE/telekit-runtime-$VER-macos-arm64.tar.gz"
```

Then run:

```sh
sh install.sh
```

The installer verifies the runtime checksum, installs telekit under
`~/.telekit-runtime/<version>/`, and links the command to
`~/.local/bin/telekit`.

If `~/.local/bin` is not on your `PATH`, the installer prints the line to add
to your shell config.

Verify:

```sh
telekit --version
```

## 3. Create Your Bot And Store Its Token

Create a Telegram bot (or reuse one you own):

1. Open Telegram and message [@BotFather](https://t.me/BotFather).
2. Send `/newbot` and follow the prompts. Copy the HTTP API token.

Store the token in the macOS Keychain:

```sh
telekit auth set-token
```

The command uses a hidden prompt. Do not pass the token as a command-line
argument, and do not put it in files or shell history.

## 4. Claim Yourself As Owner

The bridge answers exactly one person: you. Bind your chat:

```sh
telekit auth claim
```

Then send `/claim` to your bot in Telegram. The claim command binds your chat
id in the Keychain. Check with:

```sh
telekit status
```

## 5. Start The Bridge Daemon

```sh
telekit install
```

This loads a `launchd` agent that long-polls Telegram in the background and
starts at login. Logs land in `~/.telekit/bridge.log`.

To restart a running daemon later without reinstalling:

```sh
telekit restart
```

## 6. Add A Telegram Passcode (Optional)

By default, the passcode gate is disabled. To require an unlock at the start of
each Telegram session, set a passcode locally:

```sh
telekit passcode set
```

Then unlock in Telegram with:

```sh
/unlock <your passcode>
```

The unlock lasts 24 hours. `/new`, `/lock`, a daemon restart, or expiry locks
the session again. telekit tries to delete the incoming unlock message, but
Telegram deletion is best-effort; delete it manually if warned.

To disable the gate:

```sh
telekit passcode clear --yes
```

## 7. Point It At A Working Directory (Recommended)

By default the bridge runs its agent sessions in your home directory. To point it
at a specific project, set `TELEKIT_WORKING_DIR` before `telekit install`:

```sh
export TELEKIT_WORKING_DIR="$HOME/path/to/your/project"
telekit install
```

You can also register additional directories as "nodes" from inside the chat with
`/node add <name> <dir>` and switch with `/node <name>`.

## 8. Message Your Bot

Send your bot a normal message — the bridge spawns a real agent session in
your working directory and replies with its answer. Attach photos or documents
with a caption and the session reads them.

In-chat commands:

- `/help` — command overview
- `/new` — start a fresh conversation thread
- `/unlock <passcode>` — unlock a protected session
- `/lock` — lock the current session
- `/node` — list/switch the directory your messages route to
- `/harness` — show or switch the agent CLI (`claude` | `codex` | `opencode` | `sov`)
- `/effort` — show or set reasoning effort
- `/stream` — how much of a running turn is relayed live:
  `concise` (typing indicator + final answer) | `chatty` (default live stream
  with tools abstracted) | `comprehensive` (chatty plus reasoning/tool activity)
  Legacy `off`, `notes`, and `full` are still accepted as aliases.
- `/ping`, `/whoami` — liveness and chat id

## 9. If You Use A Coding Agent Locally

telekit ships an agent skill that teaches a local coding agent (e.g. Claude
Code) how to send you Telegram messages and operate the bridge:

```sh
telekit init-skill --target claude-code
```

## 10. Staying Up To Date

```sh
telekit self-update --check    # see whether a newer release exists
telekit self-update            # fetch, verify, and install it
```

Upgrades keep your `~/.telekit` state and Keychain intact, and a running
bridge daemon is restarted onto the new version automatically.

## Common Issues

- `telekit: command not found`: add `~/.local/bin` to your `PATH`.
- `claude: command not found`: install Claude Code and ensure it is on `PATH`.
- Bot never replies: check `telekit status` (token + owner + daemon), then
  `~/.telekit/bridge.log`.
- Keychain prompt fails in a headless shell: unlock your login keychain in a
  normal macOS session and retry.
- macOS blocks the binary: `xattr -dr com.apple.quarantine ~/.telekit-runtime`
  and retry.

## What To Send When Asking For Help

Share command output, not secrets:

```sh
telekit --version
telekit status
```

Do not share your bot token, Keychain items, or `~/.telekit` contents.
