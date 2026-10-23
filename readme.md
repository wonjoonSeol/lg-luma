# Luma

A native launcher for rooted LG webOS TVs, inspired by Apple TV.

English | [한국어](readme.ko.md)

## About this fork

My fork for an LG C1 on webOS 6. On top of upstream `main`, it adds **Luma as Home on webOS 6**,
which upstream's takeover doesn't support ([how it works](#luma-as-home-on-webos-6)). Until they
are merged, it also carries two icon fixes:

- Transparent icons whose logo reaches the edges, like Litefin's, keep a dark card instead of
  disappearing into a card of their own colour ([#35](https://github.com/ecklf/lg-luma/pull/35)).
- Icons show as soon as they are decoded: the Apps page fills in about 3x faster
  ([#36](https://github.com/ecklf/lg-luma/pull/36)).

<img src="docs/fork/icon-delivery-timing.png" alt="Icons on screen over time on an LG C1: before the fix the 15 icons take 751 ms to fill in, two at a time about every 107 ms; after it they take 240 ms, one every 16 ms">

<img src="docs/fork/tv-apps.webp" alt="Luma as Home on an LG C1 with webOS 6: the Apps page with each app's own icon and Korean names">

Luma as Home on my LG C1 (webOS 6.5.3), captured on the TV.

**Download:** [Luma 2.2.0 preview 2](https://github.com/wonjoonSeol/lg-luma/releases/tag/v2.2.0-preview.2).
Install the IPK with [webOS Dev Manager](https://github.com/webosbrew/dev-manager-desktop) or the
[SSH steps](#ssh) below. No build tools needed.

### Merged into Luma

These fixes started in this fork. Each one is merged into upstream `main` and released in
[v2.1.0](https://github.com/ecklf/lg-luma/releases/tag/v2.1.0):

- **Korean app names** instead of blank tiles ([#22](https://github.com/ecklf/lg-luma/pull/22),
  merged in [`14b18f8`](https://github.com/ecklf/lg-luma/commit/14b18f8)).
- **App icons** for Korean streaming and LG apps ([#18](https://github.com/ecklf/lg-luma/pull/18),
  merged in [`3e256f6`](https://github.com/ecklf/lg-luma/commit/3e256f6)).
  Since [#26](https://github.com/ecklf/lg-luma/pull/26), Luma reads every app's icon straight from the TV.
- **The right logos:** Glasshouse no longer gets the Das Erste logo
  ([#21](https://github.com/ecklf/lg-luma/pull/21), merged in [`27802ac`](https://github.com/ecklf/lg-luma/commit/27802ac)).

Still open upstream, and included in this fork's preview until they are merged:
[#35](https://github.com/ecklf/lg-luma/pull/35) and [#36](https://github.com/ecklf/lg-luma/pull/36).

**Before: Luma 2.0.3**

<img src="docs/fork/upstream.webp" alt="Luma 2.0.3's app grid: placeholder icons for TVING, wavve, Coupang Play, the LG apps and Litefin, the Das Erste logo on Glasshouse, and Korean apps with no name">

**After: with these three fixes**

<img src="docs/fork/fork.webp" alt="The same app grid with the three fixes: each app's own icon, the Glasshouse logo and Korean names">

Both show the same apps from my TV, rendered with Luma's desktop preview.

### Luma as Home on webOS 6

Upstream's takeover only runs on webOS 10 and 11. On webOS 6 it stops at a version check, and the
app manager there lacks the calls it uses to reload LG Home. But LG Home on webOS 6 is a single
program file, so `home6.sh` mounts a small launcher over that file instead. The app manager keeps
starting LG Home as usual and gets Luma. LG Home's own files stay untouched.

```mermaid
flowchart LR
  A[Home button] --> B[webOS app manager<br>starts LG Home as usual]
  B --> C["/usr/bin/com.webos.app.home<br>launcher mounted over it"]
  C --> D[Luma]
```

Install the preview, open Luma once to check it runs, then in the TV's root SSH shell:

```sh
sh /media/developer/apps/usr/palm/applications/com.ecklf.luma/home6.sh enable
```

To check it or turn it off:

```sh
sh /var/lib/luma-home6/home6.sh status
sh /var/lib/luma-home6/home6.sh disable
```

Read before you enable it:

- Tested on one TV: LG OLED48C1KNB, webOS 6.5.3.
- After a full cold boot, LG Home shows for about two minutes until the boot hook switches Home to Luma.
- With Luma as Home, opening an app can bring up LG's user agreement prompt.
- Turn off Luma's autostart hook first (`autostart.sh disable`), and disable `home6.sh` before
  uninstalling Luma.

Details are in the
[development guide](https://github.com/wonjoonSeol/lg-luma/blob/webos6-home/development.md#webos-6-home-integration),
and the source is on the [`webos6-home` branch](https://github.com/wonjoonSeol/lg-luma/tree/webos6-home).

---

_The rest of this readme is upstream's._

> [!NOTE]
> Tested on **LG OLED55C57** running **webOS 26**.\
> External testing confirms compatibility with **webOS 6 and newer**.

<table>
  <tr>
    <td width="50%" align="center">
      <img src="docs/home.png" alt="Luma native Home screen, desktop preview">
    </td>
    <td width="50%" align="center">
      <img src="docs/apps.png" alt="Luma native app library, desktop preview">
    </td>
  </tr>
  <tr>
    <td width="50%" align="center">
      <img src="docs/settings.png" alt="Luma native General settings with Quit app, desktop preview">
    </td>
    <td width="50%" align="center">
      <img src="docs/inputs.png" alt="Luma native input settings, desktop preview">
    </td>
  </tr>
</table>

## Installation

### Homebrew Channel

```text
https://github.com/ecklf/lg-luma/releases/latest/download/repo.json
```

### SSH

On your computer, replace `TV_IP`:

```sh
scp -O dist/com.ecklf.luma_2.2.0_arm.ipk root@TV_IP:/tmp/luma.ipk
ssh root@TV_IP
```

In the TV's root shell:

```sh
luna-send -i luna://com.webos.appInstallService/dev/install \
  '{"id":"com.ecklf.luma","ipkUrl":"/tmp/luma.ipk","subscribe":true}'
```

## Replacing LG Home

### Takeover Method

> [!WARNING]
> Home replacement is experimental.\
> Confirmed working on **webOS 26**.\
> Ensure to disable takeover before uninstalling Luma.

Install Luma and verify that it opens normally. Disable any Home mapping e.g.
[LG Input Hook](https://repo.webosbrew.org/apps/org.webosbrew.inputhook/) and any other Home
replacement, then run in the TV's root SSH shell:

```sh
APP=/media/developer/apps/usr/palm/applications/com.ecklf.luma
# If you enabled Lumas autostart method earlier, disable it first
# sh "$APP/autostart.sh" disable
sh "$APP/home.sh" enable
```

Takeover mounts Luma over the system Home app and reapplies the mount at cold boot.
LG Home's original files remain underneath, using the same approach as
[Glasshouse Home](https://github.com/rorygallagher2024/glasshouse/blob/main/server/lib/home-takeover.js).

To see the status or disable the home override use:

```sh
sh /var/lib/luma-home/home.sh status
sh /var/lib/luma-home/home.sh disable
```

`restore` is an alias for `disable`.

Boot log: `/var/lib/luma-home/boot.log`. See the
[development guide](development.md#optional-native-home-integration) for implementation details.

### Autostart Method

Open Luma 25 seconds after a full cold boot. Run in the TV's root SSH shell:

```sh
sh /media/developer/apps/usr/palm/applications/com.ecklf.luma/autostart.sh enable
```

Use this when takeover is disabled. It launches Luma as a regular app and does not remap the Home button.

Disable before enabling takeover or uninstalling Luma:

```sh
sh /media/developer/apps/usr/palm/applications/com.ecklf.luma/autostart.sh disable
```

### LG Input Hook Method

You can use [LG Input Hook](https://repo.webosbrew.org/apps/org.webosbrew.inputhook/), configure an Execute action with this one-line command:

```sh
/usr/bin/luna-send -n 1 -w 5000 luna://com.webos.service.applicationmanager/launch '{"id":"com.ecklf.luma"}'
```

Test on a spare button first. Disable the mapping in Input Hook to restore normal Home behavior.

## Development

### Setup & Building

From the repository root, with Nix flakes enabled:

```sh
nix develop
pnpm install --frozen-lockfile
pnpm sdk
export WEBOS_NDK="$PWD/.build/toolchain/arm-webos-linux-gnueabi_sdk-buildroot"
pnpm run package
```

The first native runtime preparation also downloads a
checksum-pinned SDL-webOS library; both downloads are cached under `.build/`.

Output:

```text
dist/com.ecklf.luma_2.2.0_arm.ipk
dist/sha256sums
dist/repo.json
dist/app-icon-large.png
```

Open [webOS Dev Manager](https://github.com/webosbrew/dev-manager-desktop), connect to the TV's
IP on port **22** as **root**, and install the IPK. Open **Luma** from the TV menu. Homebrew
Channel must be elevated; on webOS 26 use **0.8.0-rc1 or newer** for its `lunabus.query` mapping.

The native package uses **`com.ecklf.luma`** and installs separately from the old
`com.luma.launcher` web app and the former `com.luma.launcher.native` / `com.luma.native` prototypes. Native preferences
are local JSON files and are separate for each installation; browser preferences are not migrated.
Homebrew Channel treats this ID as a separate app rather than an update to the old launcher.

Wait for installation success; Ctrl+C closes an ongoing subscription. Fully close and reopen
Luma after updating. The [development guide](development.md#tv-startup-diagnostics) has a jailed
launch command that exposes errors hidden by the normal menu launch.

## Preview

```sh
nix develop
pnpm install --frozen-lockfile
pnpm assets
pnpm dev
```

The desktop preview uses sample inventory and never calls TV services. To manually exercise a
longer app grid:

```sh
pnpm dev --test-extra-apps 120
```

Preview preferences are separate from normal preferences. See [development.md](development.md)
for controls, vector rendering, diagnostics, tests and the source layout.

For release-worthy changes, include a file generated by `pnpm changeset` in your PR. The automated
Version Packages PR synchronizes app versions and publishes after merging and passing CI.
See [Releases](development.md#releases) for the workflow and repository setup.

## Privacy and scope

App/input discovery uses fixed inventory commands through Homebrew Channel's elevated service.
App launches use the native Luna bus with declared permissions. There is no demo inventory
fallback on the TV. Native caller permissions and lifecycle behavior can differ by firmware.

Favorites, hidden apps, settings, weather location and cached readings stay in local JSON files
in an app-owned persistent directory outside the installed payload.
Weather search/forecast requests go to Open-Meteo, with embedded TLS roots and bounded responses.
There is no browser geolocation, IP-based location lookup, telemetry or runtime font download.

Luma is licensed under MIT.
Luma is not affiliated with LG, Apple, Plex or any app brands shown in its UI.
