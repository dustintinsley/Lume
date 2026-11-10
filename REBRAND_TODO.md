# Streamen rebrand — follow-ups

The Lume → Streamen rename (branch `dustin-custom-v2` in all four repos) replaced
`bilipp.` → `hardheaded.`, `Lume` → `Streamen`, `lume` → `streamen` and
`LUME` → `STREAMEN`. The references below were **kept on purpose** because they
point at services and repos that live outside these repos. Renaming them before
replacements exist would break sync, downloads or links.

Find them all with:

```bash
git grep -nE 'getlume\.org|bilipp/|ghcr\.io/bilipp'
```

## External references to change later

| What | Where | Why it was kept |
|------|-------|-----------------|
| `cloud.getlume.org`, `cloud-staging.getlume.org` | StreamenCloud (`StreamenCloudAPI.officialURL` / `stagingURL`, docs) | Upstream's sync server. The Streamen app now defaults to the self-hosted `https://cloud.streamen.app` and no longer uses these. |
| `getlume.org` (privacy page, `/recorder`) | Streamen, StreamenDVR | Upstream website links. The Settings website link already points at `streamen.app`, and the support email is `support@streamen.app`. |
| `github.com/bilipp/LumeEngine/releases/download/…` | StreamenEngine `Package.swift` | Where the prebuilt `FFmpeg.xcframework` downloads from. Needs a release on the `dustintinsley/LumeEngine` fork (or a local FFmpeg build) first. |
| `lume_*` C helpers and the `lume_ffmpeg/` header folder | StreamenEngine `build/support/`, `build/scripts/make-xcframework.sh`, and the Swift files that call them | These names are compiled into the prebuilt FFmpeg download above. Rename them only together with building your own `FFmpeg.xcframework`. |
| `ghcr.io/bilipp/lumerecorder` | StreamenDVR (Docker, CI) | Upstream's published recorder image. Needs your own image on ghcr.io first. |
| `github.com/bilipp/Lume*` links, `bilipp/Lume*` repo names | READMEs, AGENTS.md, issue/security links in all repos | Point at upstream. Switch to `dustintinsley/…` (or renamed repos) when ready. |
| `bilipp/LumeAndroid` | StreamenCloud docs | Upstream Android app; no fork exists. |

## FFmpeg binary: local patched copy (this Mac only)

Since the November 2026 upstream merge, the app also links AetherEngine, whose
Dolby Vision library ships its own `module.modulemap`. Upstream's prebuilt
`FFmpeg.xcframework` (v0.3.0) has its module map at the `Headers/` root, so the
two collide ("Multiple commands produce …/include/module.modulemap").

Upstream fixed the build script (module map under `Headers/CFFmpeg/`) but has not
published a new binary. The workaround here is a copy of the v0.3.0 binary with
`CFFmpeg.h`, `CFFmpegShim.h` and `module.modulemap` moved into
`Headers/CFFmpeg/` in every slice, at `StreamenEngine/BinaryDependencies/FFmpeg.xcframework`
(git-ignored; `Package.swift` prefers it when present). A fresh clone or another
Mac doesn't have it and will hit the collision. The real fix is to build FFmpeg
with `build/scripts/make-xcframework.sh` and publish it as a release on our engine
repo, which is the same step the `lume_*` rename below needs.

If Xcode keeps using the downloaded binary after the local copy appears, clear
`~/Library/Caches/org.swift.swiftpm/manifests` and the engine's folder under the
shared package cache's `artifacts/`, then resolve packages again.

## Goal: remove every remaining "Lume"

The goal is no reference to "Lume" left anywhere, not just in the app. What's
still there, and what each needs:

- **FFmpeg helpers** (StreamenEngine): the `lume_*` C functions and the
  `lume_ffmpeg/` header folder. Rename them in `build/support/`,
  `build/scripts/make-xcframework.sh`, `Package.swift` and the Swift files that
  call them, then build our own `FFmpeg.xcframework` and publish it as a release
  on our engine repo (and point `ffmpegArtifactURL`/checksum at it). Until then
  the names must match upstream's binary.
- **GitHub repos**: rename `dustintinsley/LumeEngine`, `LumeRecorder`,
  `LumeCloud` (and `Lume`) to their Streamen names, then update the remotes and
  every `bilipp/Lume*` reference: `.github/workflows/sideload-release.yml`
  (still checks out upstream's engine, recorder and cloud), READMEs, AGENTS.md,
  the `bilipp/LumeEngine#45` comment in `StreamenEngineFailure.swift`, and the
  StreamenCloud `bilipp/LumeAndroid` docs.
- **License / notice files** (StreamenEngine `LICENSE`, `THIRD-PARTY-NOTICES.md`):
  skipped by the rebrand script. The project name and paths in them can change
  (`Tests/LumeEngineCoreTests/...` no longer exists); keep the license terms and
  the original copyright line intact.
- **Upstream links and services**: `getlume.org`, `cloud.getlume.org`,
  `ghcr.io/bilipp/lumerecorder` (see the table above). Each needs our own
  replacement first.
- **Local only**: the shared package cache `~/Library/Developer/Lume-SharedSPM`
  used in build commands. It can simply be renamed.

Note for future upstream merges: upstream keeps using the Lume names, so merge
through a rebranded copy of upstream (rebrand script on a branch, then merge
it), and check the merge didn't flip names we kept on purpose.

## Apple Developer account setup

The new identifiers don't exist yet in your Apple Developer account. Register
them before signing a build that uses them:

- App IDs: `com.hardheaded.streamen`, `com.hardheaded.streamen.StreamenWidgets`,
  `com.hardheaded.streamen.topshelf`
- App Group: `group.com.hardheaded.streamen`
- iCloud container: `iCloud.hardheaded.streamen` (then deploy the CloudKit schema,
  including `CD_SyncedRecordingServer` and `CD_SyncedBackendChoice`, to Production)
- In-app purchases (App Store Connect): `com.hardheaded.streamen.pro.monthly` as an
  **auto-renewable subscription** in a group named "Streamen Pro", and
  `com.hardheaded.streamen.premium.lifetime` as a **non-consumable**. The IDs must
  match `PremiumManager.Plan` exactly (pinned by `PremiumPlanTests`).

## Other things to know

- User defaults, keychain and store-file names were renamed too, so Streamen
  starts fresh and doesn't read data saved by an installed Lume.
- The GitHub repos themselves are still named `LumeEngine`, `LumeRecorder` and
  `LumeCloud` on `dustintinsley`; only the local folders were renamed.
- License and third-party notice files were left untouched.
- The in-app Acknowledgements screen was removed (2026-11-07). Before any
  public release, add a small "Legal & Licenses" entry back: Streamen's AGPL
  notice and source link, the GPL/LGPL libraries (KSPlayer, FFmpegKit, VLCKit,
  AetherEngine, FFmpeg) with source links, the Big Buck Bunny CC BY 3.0 credit
  for the subtitle preview, and the TMDB attribution its API terms require.
  The removed `CreditsInfo.swift` / `CreditsView.swift` are in git history.
