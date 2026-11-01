# Bundled Streamen projects

These are ordinary source directories in this Git repository, not submodules.
They are versioned and published together with the app on `dustin-custom`.

- `StreamenEngine/`: the playback engine, demo and `streamenctl`.
- `StreamenRecorder/`: recorder server, `Kit/` client, and `MacApp/` menu-bar app.
- `StreamenCloud/`: `StreamenCloudKit/` client, sync server, and protocol/vectors.

Each project retains its LICENSE, notices, instructions, and independent package
manifests. The upstream hosted URLs and binary artifact remain unchanged until
the URL migration in the root `REBRAND_FOLLOW_UP.md`.

From the repository root:

```sh
swift test --package-path Packages/StreamenEngine
swift test --package-path Packages/StreamenRecorder
swift test --package-path Packages/StreamenRecorder/Kit
swift build --package-path Packages/StreamenRecorder/MacApp
swift test --package-path Packages/StreamenCloud/StreamenCloudKit
cd Packages/StreamenCloud/server && npm ci && npm run typecheck && npm test
```

The original companion Git metadata is preserved locally in the ignored
`RepositoryHistory/` folder at the workspace root. It is not needed to build or clone
this repository and is not published as embedded Git repositories.
