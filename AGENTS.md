@~/.agents/instructions/agents.md
@./README.md

- Release tags: `v<version>`, the version of the `origin/main` commit tagged,
  by `make deploy`.
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
- The app's version is `M.m.N`. `M.m` is `major_version` and
  `minor_version` in `manifest`, raised only by the owner, never by a script
  or an agent. `N` is the commit's count on `main`, `git rev-list --count
  HEAD`, stamped into the packaged manifest's `build_version` by `make build`
  and never committed.
