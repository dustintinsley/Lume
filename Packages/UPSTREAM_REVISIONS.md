# Upstream source provenance

These source trees were imported into this repository after local warning fixes
and the Streamen rename. Their original upstream histories are retained in the
local workspace's RepositoryHistory directory; this repository tracks their
source files directly.

| Bundled project | Upstream source | Starting revision |
| --- | --- | --- |
| StreamenEngine | https://github.com/bilipp/LumeEngine | `f1c0c1f06478b729b7380012d17e40100394e667` |
| StreamenRecorder | https://github.com/bilipp/LumeRecorder | `1155dabe2ad6dc84365f72466947a7fafd203997` |
| StreamenCloud | https://github.com/bilipp/LumeCloud | `2180a86d9f589dce0cbe4edfe4f261f8fcede3ba` |

Preserve each project's LICENSE and third-party notices. The FFmpeg release URL
and checksum in StreamenEngine/Package.swift still identify the upstream binary
artifact; replacing that hosted URL is a separate migration.
