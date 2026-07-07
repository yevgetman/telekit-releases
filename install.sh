#!/bin/sh
# Install a compiled telekit runtime artifact.
#
# This installer expects to live beside VERSION, SHA256SUMS, and
# telekit-runtime-<version>-macos-<arch>.tar.gz. It installs the runtime under a
# versioned directory and points ~/.local/bin/telekit at that exact binary.
#
# It never touches ~/.telekit state or the macOS Keychain — an upgrade keeps the
# owner binding, node registry, threads, and preferences intact. If the telekit
# bridge daemon is loaded, it is restarted onto the new binary so it never keeps
# running a replaced version's code.

set -eu

prog="install.sh"

info() { printf '%s\n' "$*"; }
step() { printf '==> %s\n' "$*"; }
warn() { printf '%s: warning: %s\n' "$prog" "$*" >&2; }
err() {
	printf '%s: error: %s\n' "$prog" "$*" >&2
	exit 1
}

usage() {
	cat <<'EOF'
Usage: install.sh [--artifact <path>] [-h|--help]

Install the compiled telekit runtime for this Mac.

Options:
  --artifact <path>  Use this tarball instead of the adjacent platform artifact.
  -h, --help         Show this help.

Environment overrides:
  TELEKIT_BIN_DIR    Directory for the telekit symlink (default: ~/.local/bin).
EOF
}

artifact_opt=""
while [ "$#" -gt 0 ]; do
	case "$1" in
	--artifact)
		[ "$#" -ge 2 ] || err "--artifact requires a path"
		artifact_opt="$2"
		shift 2
		;;
	--artifact=*)
		artifact_opt="${1#--artifact=}"
		shift
		;;
	-h | --help)
		usage
		exit 0
		;;
	*)
		err "unknown argument: $1 (try --help)"
		;;
	esac
done

script_dir=$(unset CDPATH; cd -- "$(dirname -- "$0")" && pwd)

os=$(uname -s)
[ "$os" = "Darwin" ] || err "unsupported OS '$os' - telekit binary releases currently target macOS only."

machine=$(uname -m)
case "$machine" in
arm64 | aarch64) arch="arm64" ;;
x86_64 | amd64 | x64) arch="x86_64" ;;
*) err "unsupported architecture '$machine' - supported: arm64, x86_64." ;;
esac
step "Platform: macOS $arch"

# `security` (macOS Keychain) is required — it ships with macOS, so a miss means
# a broken PATH/environment. The agent harness is a runtime dependency of the
# BRIDGE only, so its absence is a warning, not an install failure.
command -v security >/dev/null 2>&1 ||
	err "missing 'security' - it ships with macOS; your PATH or environment is broken."
if ! command -v claude >/dev/null 2>&1; then
	warn "'claude' not found on PATH - the bridge daemon needs the Claude Code CLI to answer messages. Install it before 'telekit install'."
fi

version_file="$script_dir/VERSION"
[ -f "$version_file" ] || err "no VERSION file next to installer: $version_file"
IFS= read -r version <"$version_file" || [ -n "${version:-}" ] || err "could not read VERSION"
version=$(printf '%s' "$version" | tr -d '[:space:]')
[ -n "$version" ] || err "VERSION is empty"

if [ -n "$artifact_opt" ]; then
	case "$artifact_opt" in
	/*) tarball="$artifact_opt" ;;
	*) tarball="$(unset CDPATH; cd -- "$(dirname -- "$artifact_opt")" && pwd)/$(basename -- "$artifact_opt")" ;;
	esac
else
	tarball="$script_dir/telekit-runtime-$version-macos-$arch.tar.gz"
fi
[ -f "$tarball" ] || err "artifact not found: $tarball"
tarball_base=$(basename -- "$tarball")
step "Artifact: $tarball_base (v$version)"

command -v shasum >/dev/null 2>&1 || err "'shasum' not found - cannot verify artifact checksum."
sha_file="$script_dir/SHA256SUMS"
[ -f "$sha_file" ] || err "no SHA256SUMS next to installer: $sha_file"
expected=$(awk -v f="$tarball_base" '$2 == f {print $1; exit}' "$sha_file")
[ -n "$expected" ] || err "no checksum entry for '$tarball_base' in SHA256SUMS"
actual=$(shasum -a 256 "$tarball" | awk '{print $1}')
[ "$expected" = "$actual" ] || err "checksum mismatch for $tarball_base"
step "Checksum OK"

runtime_root="$HOME/.telekit-runtime"
version_dir="$runtime_root/$version"
extracted_name="telekit-runtime-$version-macos-$arch"
extracted_dir="$version_dir/$extracted_name"

mkdir -p "$version_dir"
if [ -d "$extracted_dir" ]; then
	info "runtime v$version already present at $extracted_dir - refreshing."
	rm -rf "$extracted_dir"
fi
tar -xzf "$tarball" -C "$version_dir" || err "failed to extract $tarball_base"

installed_bin="$extracted_dir/telekit-bin"
[ -f "$installed_bin" ] || err "artifact has no telekit binary at $installed_bin"
chmod +x "$installed_bin" 2>/dev/null || true
step "Installed: $installed_bin"

bin_dir="${TELEKIT_BIN_DIR:-$HOME/.local/bin}"
mkdir -p "$bin_dir"
link="$bin_dir/telekit"
tmp_link="$link.tmp.$$"
rm -f "$tmp_link"
ln -s "$installed_bin" "$tmp_link"
mv -f "$tmp_link" "$link"
step "Linked: $link -> $installed_bin"

# If the bridge daemon is loaded, restart it so it picks up the new binary —
# launchd would otherwise keep executing the replaced version until reboot.
daemon_label="com.julie.telekit-bridge"
if launchctl list 2>/dev/null | grep -q "$daemon_label"; then
	if launchctl kickstart -k "gui/$(id -u)/$daemon_label" 2>/dev/null; then
		step "Bridge daemon restarted onto v$version"
	else
		warn "could not restart the bridge daemon - run: launchctl kickstart -k gui/\$(id -u)/$daemon_label"
	fi
fi

on_path=0
case ":$PATH:" in
*":$bin_dir:"*) on_path=1 ;;
esac

info ""
info "telekit runtime v$version installed."
info "  runtime: $extracted_dir"
info "  command: $link"
if [ "$on_path" -eq 0 ]; then
	info ""
	info "NOTE: $bin_dir is not on your PATH. Add it, e.g.:"
	info "  echo 'export PATH=\"$bin_dir:\$PATH\"' >> ~/.zshrc && exec \$SHELL"
fi
info ""
info "Verify with: telekit --version"
info ""
info "First time? Wire up your bot:"
info "  1. telekit auth set-token    (paste your BotFather token)"
info "  2. telekit auth claim        (DM /claim to your bot)"
info "  3. telekit install           (load the always-on bridge daemon)"
info "  4. telekit init-skill        (optional: install the agent skill)"
