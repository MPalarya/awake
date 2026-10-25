# Awake

A tiny open-source menu bar app for Apple Silicon Macs that keeps your Mac awake, like `caffeinate -d` with an on/off switch and a timer.

**Website:** https://mpalarya.github.io/Awake/

- Apple Silicon (`arm64`) only, macOS 15 Sequoia or later
- Menu bar only: no Dock icon, no windows, no permissions to grant
- Native Swift with no dependencies. Built with Swift Package Manager
- Uses no CPU while running: it holds a single IOKit power assertion and arms one timer per timed session. Nothing polls.

## Install

### Homebrew

```sh
brew tap mpalarya/awake https://github.com/MPalarya/Awake
brew trust mpalarya/awake
brew install --cask awake
```

Homebrew 7 and later require you to trust a third-party tap before installing from it (`brew trust`).

To upgrade, run `brew upgrade` (the cask is bumped automatically on every release). To remove it, run `brew uninstall --cask awake`.

### curl

```sh
curl -fsSL https://raw.githubusercontent.com/MPalarya/Awake/main/install.sh | bash
```

This downloads the latest release, installs it into `/Applications` and launches it. Run the same command again to update.

Both methods skip the Gatekeeper warning described below.

### Manual

1. Download `Awake.dmg` from the [latest release](../../releases/latest).
2. Open the DMG and drag **Awake** into **Applications**.
3. Launch it. See the next section to get past Gatekeeper.

### Opening an unnotarized app (Gatekeeper)

Release builds are ad-hoc signed but not notarized by Apple, so macOS blocks them the first time you open them.

1. Double-click `Awake.app`. When the warning appears, click **Done**.
2. Open *System Settings → Privacy & Security* and scroll down to the message about Awake.
3. Click **Open Anyway** and confirm with your password or Touch ID.

Or, from Terminal:

```sh
xattr -dr com.apple.quarantine /Applications/Awake.app
```

## Usage

Click the cup icon in the menu bar. It is filled while Awake is on and outlined while it is off.

| Item | What it does |
| --- | --- |
| **Keep Awake** | Turns Awake on or off. |
| **Until 14:30** | Shown during a timed session. Awake turns itself off at this time. |
| **Duration** | **Indefinitely** (the default), 15 or 30 minutes, or 1, 2, 4 or 8 hours. Choosing a duration also turns Awake on. If Awake is already on, the countdown restarts. Your choice is remembered. |
| **Launch at Login** | Registers the app with `SMAppService.mainApp`. |
| **Quit Awake** | Quits the app and lets your Mac sleep normally again. |

If you quit while Awake is on with **Indefinitely** selected, it turns back on the next time it launches. This lets *Launch at Login* keep your Mac awake permanently. Timed sessions don't resume.

While Awake is on, the display and the system don't go to sleep when idle. You can still sleep the Mac from the Apple menu. Closing the lid of a MacBook still puts it to sleep unless it is connected to power and an external display (clamshell mode), just like `caffeinate`.

To check that it's working:

```sh
pmset -g assertions | grep Awake
```

## Logs and debugging

Everything is logged with `os.Logger` (subsystem `com.awake.app`):

```sh
log stream --predicate 'subsystem == "com.awake.app"'
```

## Build from source

You need Xcode 16+ or the Command Line Tools on an Apple Silicon Mac.

```sh
swift build -c release --arch arm64     # just the binary
scripts/build_app.sh                    # -> build/Awake.app (ad-hoc signed)
scripts/make_dmg.sh                     # -> build/Awake.dmg
```

`VERSION=1.2.3 scripts/build_app.sh` sets the bundle version. `CODESIGN_IDENTITY="Developer ID Application: …"` signs with a real identity instead of ad-hoc.

### Releasing

Push a tag that starts with `v`:

```sh
git tag v1.0.0 && git push origin v1.0.0
```

`.github/workflows/release.yml` then builds the arm64 app on a `macos-15` runner, packages `Awake.dmg`, attaches it to a GitHub Release for that tag, and bumps `Casks/awake.rb` on `main`.

## How it works

- **`PowerAssertion.swift`** wraps `IOPMAssertionCreateWithName` with `kIOPMAssertionTypePreventUserIdleDisplaySleep`. This is the assertion `caffeinate -d` creates, and it also prevents idle system sleep. The kernel enforces it, and macOS releases it automatically if the app exits or crashes.
- **`AppDelegate.swift`** handles the menu bar UI and Launch at Login. A timed session arms a single `Timer` for its end time. Timers don't count time the Mac spends asleep, so the deadline is re-checked against the wall clock on `NSWorkspace.didWakeNotification`.

## License

MIT
