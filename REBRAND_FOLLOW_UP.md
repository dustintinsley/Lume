# Streamen rebrand follow-up

## Hosted URLs: change in a future migration

The local projects are now Streamen, StreamenEngine, StreamenRecorder, and
StreamenCloud. The companion sources are bundled under `Packages/` in the main
GitHub repository; no separate forks or submodules are needed. Keep the existing
hosted addresses until Streamen replacements
are registered, published, and verified. Do not mechanically replace these
addresses with domains or repositories that do not exist.

- Website, privacy policy, recorder guide, and support email: `getlume.org` and
  `support@getlume.org` (`Streamen/Utils/SupportInfo.swift`, paywall, and docs).
- Cloud production and staging: `cloud.getlume.org` and
  `cloud-staging.getlume.org` (app build settings, StreamenCloudKit defaults,
  Cloudflare routes, Caddy/server documentation, and vector URLs).
- Upstream source, issues, security pages, and historical standalone CI checkouts:
  `github.com/bilipp/Lume`, `LumeEngine`, `LumeRecorder`, and `LumeCloud`.
- Pinned FFmpeg download in `Packages/StreamenEngine/Package.swift`: retain the existing
  release URL and checksum until an identical verified artifact is hosted under
  Streamen. Update both together if the binary changes.
- Recorder Docker image: `ghcr.io/bilipp/lumerecorder:latest`.
- App Store listing/review ID `6779551584`, Discord invite, and external badges:
  replace with the Streamen destinations when available.
- Rename the personal Trakt, Simkl, MDBList, and OpenSubtitles developer
  registrations to Streamen Personal where desired, preserving their client IDs
  and API keys. Authentication compatibility is separate from this rebrand.
- The main Git remote remains `https://github.com/dustintinsley/Lume.git`.
  Rename that hosted repository later if desired, then update the clone URL,
  remote, workflows, download/support links, and this checklist. Companion
  source ships with this repository; its old standalone workflows are retained
  as project history/examples and are not active nested GitHub workflows.

## Compatibility strings and historical files

The existing hosted cloud service still requires the v1 `X-Lume-Device` header
and `lume-cloud/v1/*` key-derivation/pairing domains. The parental hash salt
`lume.parental.v1` is part of that shared protocol. Keep these exact bytes until
there is a coordinated, versioned protocol migration; changing them is not a
cosmetic rename. Crypto/identity vectors retain historical sample bytes where
hashes depend on them. Source packages and public type names use Streamen.

StreamenEngine has a source-owned `StreamenFFmpegBridge` exposing renamed helper
functions while consuming the existing pinned FFmpeg framework. The framework
itself is an external binary, so its internal header names are unchanged. Future
framework builds use the renamed `streamen_ffmpeg` namespace in build/support.

Previously exported Lume IPAs/archives under the workspace Artifacts folder are
historical signed builds and have not been relabeled as Streamen builds.

## New Apple identity

- App bundle: `com.hardheaded.streamen`
- iCloud container: `iCloud.hardheaded.streamen`
- App Group: `group.com.hardheaded.streamen`
- App/widget/Top Shelf signing team remains `LU7E273YNC`.

Before distributing a signed Streamen IPA, register the new app and extension
IDs, iCloud container, and App Group in the existing Apple team, assign matching
capabilities, and generate/download the corresponding provisioning profiles.
The new identifiers represent a separate app and do not migrate the installed
Lume app's data or CloudKit records automatically.

## Optional service configuration

Local OAuth client IDs and API keys stay in the ignored `.env` file. Populate
the corresponding GitHub Actions secrets separately before expecting those
integrations in a release built by GitHub; never commit credential values.
The earlier Trakt client-ID-only authentication compatibility work is still a
separate follow-up; this rename does not implement that authentication migration.
