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
| `cloud.getlume.org`, `cloud-staging.getlume.org` | Streamen (sync config), StreamenCloud | Upstream's sync server. Needs a self-hosted StreamenCloud server first. |
| `getlume.org` (privacy page, `/recorder`) | Streamen, StreamenRecorder | Upstream website links. |
| `github.com/bilipp/LumeEngine/releases/download/…` | StreamenEngine `Package.swift` | Where the prebuilt `FFmpeg.xcframework` downloads from. Needs a release on the `dustintinsley/LumeEngine` fork (or a local FFmpeg build) first. |
| `lume_*` C helpers and the `lume_ffmpeg/` header folder | StreamenEngine `build/support/`, `build/scripts/make-xcframework.sh`, and the Swift files that call them | These names are compiled into the prebuilt FFmpeg download above. Rename them only together with building your own `FFmpeg.xcframework`. |
| `ghcr.io/bilipp/lumerecorder` | StreamenRecorder (Docker, CI) | Upstream's published recorder image. Needs your own image on ghcr.io first. |
| `github.com/bilipp/Lume*` links, `bilipp/Lume*` repo names | READMEs, AGENTS.md, issue/security links in all repos | Point at upstream. Switch to `dustintinsley/…` (or renamed repos) when ready. |
| `bilipp/LumeAndroid` | StreamenCloud docs | Upstream Android app; no fork exists. |

## Apple Developer account setup

The new identifiers don't exist yet in your Apple Developer account. Register
them before signing a build that uses them:

- App IDs: `com.hardheaded.streamen`, `com.hardheaded.streamen.StreamenWidgets`,
  `com.hardheaded.streamen.topshelf`
- App Group: `group.com.hardheaded.streamen`
- iCloud container: `iCloud.hardheaded.Streamen` (then deploy the CloudKit schema,
  including `CD_SyncedRecordingServer` and `CD_SyncedBackendChoice`, to Production)
- In-app purchase product IDs: `com.hardheaded.streamen.premium.monthly`,
  `com.hardheaded.streamen.pro.monthly`, `com.hardheaded.streamen.premium.lifetime`

## Other things to know

- User defaults, keychain and store-file names were renamed too, so Streamen
  starts fresh and doesn't read data saved by an installed Lume.
- The GitHub repos themselves are still named `LumeEngine`, `LumeRecorder` and
  `LumeCloud` on `dustintinsley`; only the local folders were renamed.
- License and third-party notice files were left untouched.
