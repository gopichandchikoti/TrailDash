# TrailDash

[![CI](https://github.com/gopichandchikoti/TrailDash/actions/workflows/verify.yml/badge.svg)](https://github.com/gopichandchikoti/TrailDash/actions/workflows/verify.yml)

**Find your line above the clouds.** An original, offline 3D endless runner through a midnight
skybridge garden. Guide a tiny courier between coral cargo, mint gates and tall garden pylons,
collecting amber light tokens as the trail gets faster.

![TrailDash on the Android emulator](docs/evidence/android-home.png)

TrailDash runs on Android phones and in the Godot editor for desktop testing. No account, backend,
ads or network connection is required.

> Android package: **com.portfolio.traildash** ? Android **7.0 / API 24+** ? Source version **0.1.0**

## Download (Android)

**[Download the latest APK](https://github.com/gopichandchikoti/TrailDash/releases/download/latest-build/TrailDash-preview.apk)**

This URL stays the same. Every successful push to `main`, including documentation changes, checks the
source, builds and verifies the APK, then replaces the `latest-build` preview download. A failing
build leaves the previous working download available. Also:
[SHA-256 checksum](https://github.com/gopichandchikoti/TrailDash/releases/download/latest-build/TrailDash-preview.apk.sha256) ?
[build identity and evidence](https://github.com/gopichandchikoti/TrailDash/releases/download/latest-build/build-evidence.json) ?
[release notes](https://github.com/gopichandchikoti/TrailDash/releases/tag/latest-build) ?
[all releases](https://github.com/gopichandchikoti/TrailDash/releases).

**Install:** download the APK on an Android phone, allow installation from the browser or file manager
when Android asks, then open the file. This package supports ARM64 phones and x86_64 emulators.
Compare `Get-FileHash TrailDash-preview.apk -Algorithm SHA256` or `sha256sum TrailDash-preview.apk`
with the checksum before installing if you want to check the download.

These are **debug-signed development previews**, not store releases. CI uses a stable preview key,
matching the existing local debug build, so newer previews install over older copies and preserve
records/settings. Uninstalling deletes local progress. Builds signed with another certificate cannot
update this installation in place. Production signing and physical-phone release validation remain open.

## What it does

| Area | What you get |
| --- | --- |
| **Run** | Three lanes, smooth lane changes, jump over cargo, slide under gates, go around garden pylons |
| **Progression** | Speed rises from 12 to 26 m/s; five difficulty bands; seeded procedural rows with an adjacent open route |
| **Score** | Distance, light tokens and consecutive-token combos up to 4?; best score and distance saved locally |
| **Rewards** | Earned tokens unlock coral and lilac courier colors for 60 tokens each; badges at 500, 1,500 and 3,000 m |
| **Controls** | Four swipe directions, optional touch buttons, keyboard fallback and remappable keyboard bindings |
| **Session** | Tutorial, countdown, pause, results, retry and main menu; backgrounding/Android Back pauses play |
| **Settings** | Sound, haptics, reduced effects, touch buttons and 30 FPS battery mode |
| **Privacy** | No login, ads, analytics or network access; optional vibration is the only Android permission |

## Quick start (desktop)

Install **Godot 4.7.2 stable**. In PowerShell:

```powershell
git clone https://github.com/gopichandchikoti/TrailDash.git
cd TrailDash
$env:GODOT_BIN = 'C:\path\to\Godot_v4.7.2-stable_win64_console.exe'
& $env:GODOT_BIN --editor --path .
```

Open `project.godot` and press **F5**, or run `& $env:GODOT_BIN --path .`.

## Use the app

1. Choose **Let's run**. First-time players see the tutorial, followed by a three-second countdown.
2. Swipe left/right to change lane, up to jump coral cargo, down to slide under mint gates.
   Tall garden pylons require a lane change. Touch buttons provide the same actions.
3. Follow amber rings. Consecutive collections raise the multiplier to 4?; missing a ring resets it.
4. Tap Pause, press Android Back, or leave the app to pause. Resume explicitly when ready.
5. After a collision, inspect your score, distance, tokens and best streak. **Run it back** starts fresh.
6. Open Settings for audio, haptics, reduced effects, touch buttons, battery mode and key bindings.
   Courier colors uses tokens from completed runs; choosing an owned color is free.

| Action | Phone | Keyboard |
| --- | --- | --- |
| Change lane | Swipe left/right or arrow buttons | Left/right arrows, A/D |
| Jump | Swipe up or Jump | Up arrow, W, Space |
| Slide | Swipe down or Slide | Down arrow, S |
| Pause / resume | Pause or Android Back | P / Esc |

Completed results and settings survive relaunch and same-key updates. An unfinished run is discarded
if the process dies or you choose Main menu. Returning home resets the courier pose and track.

## Run it

### Desktop and source checks

Use Python **3.13** and the console Godot executable above:

```powershell
python -m venv .venv
.\.venv\Scripts\python.exe -m pip install -r requirements-dev.txt
.\.venv\Scripts\python.exe tools/verify.py --lint-bin .venv/Scripts
```

There are no Godot add-ons or external runtime dependencies. English is the only authored locale.
All authored content lives in `public/traildash.model.json`; no web server or `.env` file is used.
After editing the model, regenerate the bundled fallback with `python tools/content.py`.

### Android

Use matching Godot export templates, **JDK 17**, Android SDK platform **36**, build-tools **36.0.0**
and platform-tools. Configure Android SDK/Java SDK paths in Godot's Editor Settings.

```powershell
$env:ANDROID_HOME = 'C:\path\to\android-sdk'
$env:JAVA_HOME = 'C:\path\to\jdk-17'
.\tools\build-android.ps1
# Build, verify, install and launch on one selected device:
.\tools\build-android.ps1 -Device YOUR_DEVICE_SERIAL
```

The local build writes `builds/traildash-0.1.0-debug.apk` and its checksum. The shared Python build
helper verifies the package, SDK levels, architecture, permissions, launcher, signature and content.
Local and CI Android version codes use UTC seconds since 2024-01-01, independent of workflow counters.
Godot's prebuilt Android template avoids Gradle and third-party SDK plugins for this project.

## Releases and CI

One workflow, [.github/workflows/verify.yml](.github/workflows/verify.yml), handles verification,
Android packaging and publication:

| Event | What happens |
| --- | --- |
| **Every push to `main`** | Validate content, Python packaging checks, GDScript format/lint, headless import and gameplay tests; export/sign/verify the APK; refresh the fixed `latest-build` download |
| **Pull request** | Run the same checks and build an APK with an isolated review-only key; upload a workflow artifact; no signing secrets or release publication |
| **Manual run on `main`** | Verify/build and refresh the preview using the same gates |
| **Failed checks or stale commit** | Preserve the previous download; older runs cannot overwrite a newer main commit or APK version |

The publisher has write permission but runs no project code. Build jobs have read-only repository
permission. The engine, templates and action revisions are pinned; downloadable bytes are the same
bytes that passed APK verification. Preview publication is serialized and is not canceled midway.

The source version comes from `project.godot`; CI appends `-preview.<versionCode>` to Android's displayed
version. Release notes and `build-evidence.json` identify the exact source commit, workflow run, APK
hash, certificate fingerprint and signing mode. `latest-build` is a prerelease and does not replace
an immutable official release. Tagged/store releases are not automatically published by this workflow.

**Preview signing:** four repository secrets hold the existing preview key:
`ANDROID_PREVIEW_KEYSTORE_BASE64`, `ANDROID_PREVIEW_KEYSTORE_PASSWORD`, `ANDROID_PREVIEW_KEY_ALIAS`,
`ANDROID_PREVIEW_KEY_PASSWORD`. The public `TRAILDASH_PREVIEW_CERT_SHA256` repository variable pins its
certificate. Keep the original keystore backed up outside Git. Main-branch publication fails if the
key is missing, incomplete or different. PRs use a throwaway key and cannot update a preview install.

## Verify

```powershell
.\.venv\Scripts\python.exe tools/verify.py --lint-bin .venv/Scripts
.\.venv\Scripts\python.exe -m unittest discover -s tests -p 'test_*.py'
```

The suite includes **30,174 GDScript assertions**, 10,000 seeded rows, a three-minute simulation using
the actual player/world code and Python release-tool checks. It covers input cancellation/HUD routing,
state transitions, fairness, scores, save recovery and return-to-menu resets. Assertion counts are not
coverage percentages. Engine errors fail the checks even if Godot exits with code zero.

APK verification also rejects wrong versions, extra permissions, missing ABIs/launcher/content and an
unexpected signing certificate. Local logs and packages are under ignored `builds/`.

## Project layout

```text
scenes/     Godot entry scene
scripts/    Run rules, character, pooled world, input, menus, content, audio and saves
public/     Single traildash.model.json content source
assets/     Original application icon and import settings
tests/      Godot domain/scene/input checks and Python packaging checks
tools/      Content generation, source checks, Android export and APK verification
.github/    One CI/build/preview-release workflow
docs/       Architecture, engine ADR and actual emulator screenshots
builds/     Generated APKs, checksums and logs (ignored by Git)
```

## Documentation

- **[Architecture guide](docs/architecture.md):** source ownership, feature flows, save schema, Android
  boundary, security, design, release pipeline, requirements, verification and extension instructions.
- **[Engine ADR](docs/adr/001-godot4-mobile-runner.md):** Godot/GDScript and Compatibility-renderer decision.
- **[Asset notices](ASSET_LICENSES.md):** provenance and packaged engine/font notices.

## Status and troubleshooting

This is a playable development MVP verified on an Android 15 emulator. Real swipes, jump/slide,
collecting, pause/resume, results/retry, settings and same-key persistence have been exercised.
Physical phones, sustained frame pacing/thermals, refresh-rate/notch variations, screen readers and
production signing remain unverified. The 60 FPS target is a budget, not a measured hardware claim.

- Emulator shader failure mentioning `GL_MAX_FRAGMENT_UNIFORM_VECTORS`: the local host-GPU emulator
  rendered correctly with `-gpu host`; the affected SwiftShader configuration did not.
- A shader-cache recompile warning at startup has been observed; repeated program-link failures need logs.
- Saving failure shows a warning and preserves the previous save. Validated backup recovery is explicit.
- Android downgrade/signature refusal: verify version/certificate in the release evidence. Avoid
  uninstalling unless you accept losing local progress; same-key newer previews preserve it.

## Third-party software

Godot Engine and its bundled default font include third-party components; full engine and dependency
license texts are available in **Settings ? Credits & licenses**. Original geometry, icon and synthesized
sounds are authored for TrailDash; no proprietary runner assets were copied. See [asset notices](ASSET_LICENSES.md).
The owner has not selected a public source/art license.
