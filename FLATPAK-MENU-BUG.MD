# Flatpak apps missing from the app menu (stale ksycoca from future mtimes)

**Investigated:** 2026-10-01 on a freshly installed Caracal Kinoite machine (bare metal).
**Status:** Root cause fully traced and proven on-machine. Not a bug in the flatpak install logic itself.
**Related change:** jasonn3 → Titanoboa ISO rework (branch not yet pushed) — see "What to check against the branch".

---

## TL;DR

The machine's clock was wrong during install (RTC ~7h ahead; NTP corrected it during first boot). The ISO's offline flatpak deploy therefore wrote `/var/lib/flatpak` with **mtimes in the future**. KDE's service cache (`~/.cache/ksycoca6_*`) recorded those future dir mtimes as its "last built" stamps, and its rebuild heuristic (`mtime > stored stamp`) silently never fires again → the app menu froze at its first-login state (only the ISO-baked Waterfox + Bazaar). Everything installed later (Proton apps, ente, Tenacity, ...) was invisible in the menu and KRunner search, permanently, across reboots. A forced `kbuildsycoca6 --noincremental` fixes the machine permanently.

Not reproducible in a VM with a sane clock (host injects the clock → no future mtimes → KDE's normal self-heal works).

---

## Symptoms

- Apps installed after first login (via Bazaar) never appear in the KDE app menu / KRunner search.
- Bazaar's "Open" worked in the boot where the installs happened (12 successful `app-flatpak-me.proton.*` scope launches in the journal), then produced no launch attempt and no error in later boots. Not reproducible anymore; the exact launch path was proven working end-to-end during this investigation.
- The preinstalled offline flatpaks (Waterfox, Bazaar) always showed fine.
- Bazaar itself launches fine; the app store, installs, and updates all work normally.

---

## Root cause chain (proven)

1. **Wrong RTC during install.** Journal (boot -6): starts `22:48:29`, NTP-corrected to `15:47:59` ~1 min later — clock was ~7h ahead while Anaconda ran. ISO offline flatpak deploy wrote files with that wrong clock:
   ```
   $ stat -c '%y %n' /var/lib/flatpak/app/net.waterfox.waterfox/current/active/export/share/applications/net.waterfox.waterfox.desktop
   2026-10-01 22:47:01... +1000        # ~2h in the future even now
   ```
   `/usr/share` is immune (ostree/composefs normalizes to epoch); `/var/lib/flatpak` is not.
2. **First sycoca build succeeds** (scanning ignores future mtimes) at first login and records `/var/lib/flatpak/exports/share/applications` with its future mtime as the "built at" stamp.
3. **KF6 kservice self-heal silently no-ops.** `KSycocaPrivate::needsRebuild()` → `TimestampChecker::checkDirectoriesTimestamps()` rebuilds only when a dir's current mtime is **newer** than the stored stamp. Every later real change (preinstall 15:47–15:48, user installs 15:49–15:52, anything after) has mtime < future stamp → never rebuilds. The future stamp is stored inside the cache file, so the breakage persists across reboots.
4. **Nothing in Caracal ever refreshes the cache.** `flatpak-preinstall.service`/`.timer`, the `flatpak update` inside it, `caracal-flatpak-setup`, `70-caracal-flatpaks.just` — none run `kbuildsycoca6`. Menu correctness relies entirely on KDE's mtime heuristic.
5. **Heal is permanent once real stamps are recorded.** After `kbuildsycoca6 --noincremental`, plain (incremental) `kbuildsycoca6` correctly detects new installs again (verified live with a test install).

Launch path itself is fine (verified): Bazaar runs `flatpak-spawn --host flatpak run %s` (string in its own binary); Proton Mail was started end-to-end through that exact path during the investigation.

---

## Key evidence

| Fact | Evidence |
|---|---|
| Future mtimes on baked flatpak content | `stat` on waterfox deploy file + `/var/lib/flatpak/exports/share/applications/io.github.kolunmi.Bazaar.desktop` → `2026-10-01 22:47` (future); `/var/lib/flatpak/exports/share/icons` still `22:47` |
| Clock corrected mid-first-boot | `journalctl --list-boots`: boot -6 first entry `22:48:29`, last `15:47:59` |
| Menu cache predates installs | sycoca mtime `15:46:28` vs flatpak history pulls `15:47:11–15:52:10`; cache unchanged (md5) across the 18:32 boot and a krunner query |
| Manual rebuild fixes content | `kbuildsycoca6 --noincremental` → `kbuildsycoca6 --menutest` then lists me.proton.Mail/Pass/VPN, ente, tenacity, ... |
| Open worked then stopped | boot -5: 12 proton scope launches; boots -4..0: zero proton scopes, Bazaar GUI itself fine, no error lines |
| VM unaffected | user report; consistent with sane host-injected clock |

---

## What to check against the Titanoboa branch

The trigger is **when/where the flatpaks are deployed relative to the target's clock**. Checklist:

- [ ] **Where are flatpaks installed now?** Build-side bake into the image (`/var/lib/flatpak` in the OCI layers) vs target-side deploy during Anaconda/first boot. Build-side = the future-mtime window disappears entirely (build host clock is always in the past relative to any install date). This is the acceptance criterion.
- [ ] **No target-side flatpak deploy left behind:** grep the ISO build workflow/kickstart for `flatpak` / `FLATPAK_REMOTE_REFS` / jasonn3 remnants. If any target-side deploy remains, the wrong-clock install can still recreate the bug.
- [ ] **Mtimes of baked content:** on a fresh install of the new ISO,
      `sudo find /var/lib/flatpak -newermt "$(date '+%Y-%m-%d %H:%M')" | head`
      must return **nothing** (no files/dirs with future mtimes).
- [ ] **Offline install still works** (flatpaks present with no network) — bake must include the full runtime/locale closure (current `installer/generate-flatpak-refs.sh` does this; make sure the equivalent survives).
- [ ] **Regression test:** on a new install, install an app via Bazaar after login → it must appear in the menu without logout (KDE self-heal on sane clocks).
- [ ] Optional hardening (independent of the branch): run `kbuildsycoca6` as the user after flatpak changes (e.g. a user `systemd.path` unit watching `/var/lib/flatpak/exports/share/applications`), and/or normalize future mtimes in `flatpak-preinstall` (`find /var/lib/flatpak -newermt now -exec touch -h {} +`). Cheap insurance against any future wrong-clock path.
- [ ] Deliberate repro to validate the fix (VM ok): before install, set the clock ahead (installer tty: `timedatectl set-time "+8 hours"` or set RTC in firmware), install **offline**, first-boot with network so NTP corrects the clock, then install an app via Bazaar. Old flow: app missing from menu. Fixed flow (build-side bake): app present, and `find /var/lib/flatpak -newermt now` empty.

### Side findings (unrelated to this bug, noticed while tracing)

- `bazaar.service` (user unit, "shell search results" daemon) ships but is **never enabled** (`disabled; preset: disabled`, inactive). `caracal-flatpak-setup` even does `systemctl --user try-restart bazaar.service` on it. Either enable it in user setup or drop the unit.
- First-boot `caracal-user-setup.service` failed once (`status=1/FAILURE` at 15:46:24, boot -6); the post-session run completed fine. Cause not investigated.
- plasmashell logged `Terminal "com.mitchellh.ghostty.desktop" not found, service "Neovim"` during the broken-cache period (breaks terminal=true .desktop launches, e.g. nvim). ghostty is installed and is indexed after the cache rebuild — likely the same poisoning; retest if reported.

---

## Workaround for affected users (copy-paste for GitHub issues)

```bash
# 1. Confirm the signature: an mtime in the future vs `date`
date
stat -c '%y %n' /var/lib/flatpak/exports/share/applications

# 2. Fix future mtimes so the problem cannot recur on that machine
sudo find /var/lib/flatpak -newermt "$(date '+%Y-%m-%d %H:%M')" -exec touch -h {} +

# 3. Force-rebuild the KDE app cache (plain `kbuildsycoca6` will NOT detect
#    this — the change-detection is exactly what is broken)
kbuildsycoca6 --noincremental
```

Apps appear immediately (running KDE apps pick the new cache up via file watch); worst case log out and back in. Verify with `kbuildsycoca6 --menutest | grep -i <app-id>` or just the menu.

Why `--noincremental`: on affected machines the incremental check compares dir mtimes against the future stamp stored in the old cache and always concludes "nothing changed" — forcing the rebuild is the point. After this one forced rebuild the stored stamps are real and normal behavior resumes permanently.
