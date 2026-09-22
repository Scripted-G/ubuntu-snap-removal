#!/usr/bin/env bash
set -Eeuo pipefail

# remove-snap-ubuntu-26.04.sh
# Target: Ubuntu 26.04 LTS (Classic desktop installation)
# Purpose: Remove installed snaps, purge snapd, remove per-user Snap data,
#          and prevent APT from reinstalling snapd.

log() {
    printf '\n==> %s\n' "$*"
}

fail() {
    printf '\nERROR: %s\n' "$*" >&2
    exit 1
}

# Run this script as a normal user. It will use sudo only where required.
if [[ ${EUID} -eq 0 ]]; then
    fail "Run this script as your normal user, not with sudo. The script will request sudo when needed."
fi

# Verify the intended Ubuntu release.
[[ -r /etc/os-release ]] || fail "/etc/os-release could not be read."
# shellcheck disable=SC1091
source /etc/os-release

[[ ${ID:-} == "ubuntu" ]] || fail "This script is intended for Ubuntu only."
[[ ${VERSION_ID:-} == "26.04" ]] || fail "This script currently targets Ubuntu 26.04 only. Detected: ${VERSION_ID:-unknown}."

log "Ubuntu 26.04 detected."

# Authenticate once near the beginning so failures happen before destructive work.
sudo -v

if command -v snap >/dev/null 2>&1; then
    log "Removing installed snaps."

    # Remove everything except the snapd snap first. Repeated passes allow
    # dependent application/content/base snaps to disappear in a safe order
    # without hard-coding package names.
    while true; do
        mapfile -t snaps < <(
            snap list 2>/dev/null \
                | awk 'NR > 1 && $1 != "snapd" {print $1}' \
                | sort -u
        )

        ((${#snaps[@]} == 0)) && break

        removed_this_pass=0

        for snap_name in "${snaps[@]}"; do
            printf 'Trying to remove: %s\n' "$snap_name"
            if sudo snap remove --purge "$snap_name"; then
                removed_this_pass=1
            else
                printf '  Deferred: %s (it may still be required by another snap)\n' "$snap_name"
            fi
        done

        if ((removed_this_pass == 0)); then
            printf '\nThe script could not make further progress removing snaps.\n' >&2
            printf 'Remaining snaps:\n' >&2
            snap list >&2 || true
            fail "Stopping rather than forcing removal."
        fi
    done

    # The snapd snap, if present, must be removed after the other snaps.
    if snap list 2>/dev/null | awk 'NR > 1 {print $1}' | grep -Fxq snapd; then
        log "Removing the snapd snap last."
        sudo snap remove --purge snapd
    fi
else
    log "The snap command is not present; skipping snap removal."
fi

# Purging the Debian package is the supported cleanup step for snapd on
# Classic Ubuntu and removes its system data directories.
if dpkg-query -W -f='${db:Status-Status}\n' snapd 2>/dev/null | grep -Fxq installed; then
    log "Purging the snapd Debian package."
    sudo apt-get purge -y snapd
else
    log "The snapd Debian package is already absent."
fi

# Remove per-user Snap data that package purge does not remove.
log "Removing remaining Snap data for the current user and root, if present."
sudo rm -rf -- "$HOME/snap" "$HOME/.snap" /root/snap /root/.snap

# Prevent APT from selecting any version of snapd in the future.
log "Creating APT preference to prevent snapd from being reinstalled."
sudo tee /etc/apt/preferences.d/no-snap.pref >/dev/null <<'PREF'
Package: snapd
Pin: version *
Pin-Priority: -10
PREF

log "Verifying the final state."

verification_failed=0

if command -v snap >/dev/null 2>&1; then
    printf 'FAIL: snap command is still available at %s\n' "$(command -v snap)" >&2
    verification_failed=1
else
    printf 'PASS: snap command is absent.\n'
fi

if dpkg-query -W -f='${db:Status-Status}\n' snapd 2>/dev/null | grep -Fxq installed; then
    printf 'FAIL: snapd is still installed as a Debian package.\n' >&2
    verification_failed=1
else
    printf 'PASS: snapd Debian package is not installed.\n'
fi

policy_output=$(apt-cache policy snapd)
printf '\n%s\n' "$policy_output"

if grep -Fq 'Candidate: (none)' <<<"$policy_output"; then
    printf 'PASS: APT has no snapd installation candidate.\n'
else
    printf 'FAIL: APT still has a snapd installation candidate.\n' >&2
    verification_failed=1
fi

if ((verification_failed != 0)); then
    fail "One or more verification checks failed. Review the output above."
fi

log "Snap removal and APT blocking completed successfully."
