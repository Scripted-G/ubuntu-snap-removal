# 🧹 Ubuntu Snap Removal

A Bash script for removing Snap from **Ubuntu 26.04 LTS**, cleaning related user data,
and preventing `snapd` from being selected for reinstallation by APT.

The script was created from a manually tested removal process, then revised to avoid
hard-coding the names of installed snaps and to verify the final system state.

---

## 🎯 What It Does

The script:

- verifies that the system is running **Ubuntu 26.04**
- requires execution as a normal user rather than as root
- discovers the snaps that are actually installed
- removes installed snaps with `--purge`
- makes repeated removal passes so snap dependencies can be resolved without a
  hard-coded package list
- removes the `snapd` snap last, if it is present
- purges the Debian `snapd` package
- removes remaining Snap data from the current user and root accounts
- creates an APT preference that blocks all versions of `snapd`
- verifies that:
  - the `snap` command is gone
  - the Debian `snapd` package is not installed
  - APT reports no installation candidate for `snapd`

---

## ⚠️ Important

This script intentionally removes Snap and associated per-user Snap data.

It deletes these directories if they exist:

```text
~/snap
~/.snap
/root/snap
/root/.snap
```

If you have Snap applications containing data you want to keep, back that data up
before running the script.

This project currently targets **Ubuntu 26.04 LTS Classic installations only**.
Do not use it on Hybrid Classic installations that rely on Snap for essential
system functionality, such as Ubuntu 26.04 systems installed with TPM-backed
full-disk encryption.

---

## 🧪 Testing

The script has been tested successfully on a fresh Ubuntu 26.04 LTS virtual machine after
initial system updates.

Test environment:

| Component | Test Environment |
|---|---|
| Guest OS | Ubuntu 26.04 LTS |
| Hypervisor | QEMU/KVM |
| Management | libvirt + virt-manager |
| Test state | Fresh installation with initial updates applied |

A successful run ended with verification similar to:

```text
PASS: snap command is absent.
PASS: snapd Debian package is not installed.
PASS: APT has no snapd installation candidate.

==> Snap removal and APT blocking completed successfully.
```

Additional testing on other Ubuntu 26.04 installations is welcome.

---

## 🚀 Usage

Clone the repository:

```bash
git clone git@github.com:Scripted-G/ubuntu-snap-removal.git
cd ubuntu-snap-removal
```

Make the script executable:

```bash
chmod +x remove-snap-ubuntu-26.04.sh
```

Run it as your **normal user**:

```bash
./remove-snap-ubuntu-26.04.sh
```

Do **not** run the entire script with `sudo`.

The script requests `sudo` privileges itself only where administrative access is
required.

---

## 🔒 Preventing `snapd` From Returning

After Snap is removed, the script creates:

```text
/etc/apt/preferences.d/no-snap.pref
```

with:

```text
Package: snapd
Pin: version *
Pin-Priority: -10
```

The negative APT priority prevents available versions of `snapd` from being selected
as an installation candidate.

The script checks this at the end with:

```bash
apt-cache policy snapd
```

A successful result should show:

```text
Installed: (none)
Candidate: (none)
```

with available `snapd` versions listed at priority `-10`.

---

## 🧠 Why the Script Discovers Installed Snaps

A fresh Ubuntu installation may not always contain exactly the same Snap packages.

Instead of maintaining a fixed list such as:

```text
firefox
snap-store
core24
...
```

the script uses `snap list` to discover the packages actually installed on the
machine.

It then makes repeated removal passes. Snaps that cannot yet be removed because
another installed snap depends on them are deferred until a later pass.

If an entire pass completes without removing anything, the script stops rather than
forcing removal or looping indefinitely.

---

## ✅ Final Verification

The script does not treat successful command execution alone as proof that the job is
complete.

Before reporting success, it verifies all three of the following conditions:

1. `snap` is no longer available
2. the Debian `snapd` package is not installed
3. APT has no installation candidate for `snapd`

If any check fails, the script exits with an error and reports which verification
failed.

---

## 📁 Repository Contents

```text
ubuntu-snap-removal/
├── LICENSE
├── README.md
└── remove-snap-ubuntu-26.04.sh
```

---

## 🛠️ Current Scope

The current version intentionally supports only **Ubuntu 26.04 LTS**.

Possible future work may include:

- testing additional Ubuntu releases
- adding release-specific handling where necessary
- expanding test coverage across different fresh-install configurations

Support for other releases will only be added after their behavior has been verified.

---

## 📜 License

This project is released under the [MIT License](LICENSE).
