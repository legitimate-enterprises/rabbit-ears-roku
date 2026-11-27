@~/.agents/instructions/agents.md
@./README.md

- Release tags: `v<version>`, at the version `manifest` states, by
  `make deploy`.
- Red-green: write the failing test first, then the minimum code. Judge
  coverage by the defects caught at seams: the API boundary, playback, the
  release script against a Roku.
- Comments explain intent, invariants and side effects of non-obvious code.
  Never what the code does, never history or rationale.
- No Markdown beyond `README.md`, `AGENTS.md` and `memory.md`. No ADRs, no
  decision logs.
- `openapi.yaml` is the server's file, replaced whole by `make spec` and
  never edited here. Its `info.version` is the server release the app is
  built against, and the app may assume that API.
- The app's version is `M.M.P`: `major_version`, `minor_version` and
  `build_version` in `manifest`, raised in the first change after a release
  tag.
