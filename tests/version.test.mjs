// The version M.m.N: M.m from manifest, N the commit count. Runs the
// Makefile's stamp and scripts/cut-release.sh in throwaway repositories,
// the script against a bare origin, so nothing here touches build/ or GitHub.
import { test } from "node:test";
import assert from "node:assert/strict";
import { execFileSync, spawnSync } from "node:child_process";
import { chmodSync, copyFileSync, mkdirSync, mkdtempSync, readFileSync, rmSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";

const root = new URL("..", import.meta.url).pathname;
const MANIFEST = "title=Rabbit Ears\nmajor_version=7\nminor_version=2\nui_resolutions=fhd\n";

const git = (dir, ...args) =>
  execFileSync("git", ["-c", "user.name=t", "-c", "user.email=t@t", "-c", "commit.gpgsign=false", ...args], {
    cwd: dir,
    encoding: "utf8",
  }).trim();

// commit(dir, file, text): one commit writing file, or an empty one without it.
function commit(dir, file, text) {
  if (file) writeFileSync(join(dir, file), text);
  git(dir, "add", ".");
  git(dir, "commit", "--quiet", "--allow-empty", "-m", file ?? "empty");
}

function repo() {
  const dir = mkdtempSync(join(tmpdir(), "roku-version-"));
  git(dir, "init", "--quiet", "-b", "main");
  mkdirSync(join(dir, "scripts"));
  mkdirSync(join(dir, "source"));
  copyFileSync(join(root, "scripts/cut-release.sh"), join(dir, "scripts/cut-release.sh"));
  chmodSync(join(dir, "scripts/cut-release.sh"), 0o755);
  writeFileSync(join(dir, ".gitignore"), "build/\norigin.git/\nshallow/\n");
  commit(dir, "manifest", MANIFEST);
  return dir;
}

function withRepo(run) {
  const dir = repo();
  try {
    return run(dir);
  } finally {
    rmSync(dir, { recursive: true, force: true });
  }
}

const run = (dir, cmd, ...args) => {
  const r = spawnSync(cmd, args, { cwd: dir, encoding: "utf8" });
  return { code: r.status, out: r.stdout + r.stderr };
};
const stamp = (dir) => run(dir, "make", "--no-print-directory", "-f", join(root, "Makefile"), "build/manifest");
const cut = (dir, ...args) => run(dir, "scripts/cut-release.sh", ...args);

test("the build stamps the commit count into a copy of the manifest", () =>
  withRepo((dir) => {
    commit(dir);
    commit(dir);
    let { code, out } = stamp(dir);
    assert.equal(code, 0, out);
    assert.equal(readFileSync(join(dir, "build/manifest"), "utf8"), `${MANIFEST}build_version=3\n`);
    commit(dir);
    ({ code, out } = stamp(dir));
    assert.equal(code, 0, out);
    assert.match(readFileSync(join(dir, "build/manifest"), "utf8"), /\nbuild_version=4\n$/);
    assert.equal(readFileSync(join(dir, "manifest"), "utf8"), MANIFEST);
    assert.equal(git(dir, "status", "--porcelain"), "");
  }));

test("a shallow clone, which cannot count commits, builds nothing", () =>
  withRepo((dir) => {
    commit(dir);
    git(dir, "clone", "--quiet", "--depth", "1", `file://${dir}`, "shallow");
    const { code, out } = stamp(join(dir, "shallow"));
    assert.notEqual(code, 0);
    assert.match(out, /shallow clone/);
    assert.equal(spawnSync("test", ["-e", join(dir, "shallow/build/manifest")]).status, 1);
  }));

test("--check accepts only v<M.m> of the manifest and the commit count of HEAD", () =>
  withRepo((dir) => {
    commit(dir);
    commit(dir);
    assert.equal(cut(dir, "--check", "v7.2.3").code, 0);
    for (const tag of ["v7.2.2", "v7.2.4", "v7.2", "v7.2.03", "7.2.3"]) {
      const { code, out } = cut(dir, "--check", tag);
      assert.notEqual(code, 0, tag);
      assert.match(out, new RegExp(`${tag} is not v7\\.2\\.3, the version of HEAD`), tag);
    }
  }));

// A clone of a bare origin, where cut-release.sh reads origin/main.
function withOrigin(run) {
  return withRepo((dir) => {
    git(dir, "clone", "--quiet", "--bare", dir, "origin.git");
    git(dir, "remote", "add", "origin", join(dir, "origin.git"));
    git(dir, "fetch", "--quiet", "origin");
    return run(dir, () => git(dir, "push", "--quiet", "--tags", "origin", "main"));
  });
}

test("make deploy offers v<M.m> of the manifest and the commit count of origin/main", () =>
  withOrigin((dir, push) => {
    commit(dir, "source/main.brs", "a");
    push();
    commit(dir, "source/main.brs", "unpushed");
    const { code, out } = cut(dir);
    assert.equal(code, 0, out);
    assert.match(out, /^7\.2\.2 is ready: v7\.2\.2\n/);
  }));

test("a tag on origin/main, or only changes outside the app since one, is nothing to release", () =>
  withOrigin((dir, push) => {
    commit(dir, "source/main.brs", "a");
    git(dir, "tag", "v7.2.2");
    push();
    assert.match(cut(dir).out, /^7\.2\.2 is released\n/);
    commit(dir, "README.md", "docs");
    push();
    assert.match(cut(dir).out, /^nothing in the app has changed since v7\.2\.2\n/);
    commit(dir, "source/main.brs", "b");
    push();
    assert.match(cut(dir).out, /^7\.2\.4 is ready: v7\.2\.4\n/);
  }));

test("a version below the newest release is refused until the owner raises M.m", () =>
  withOrigin((dir, push) => {
    git(dir, "tag", "v8.0.1");
    commit(dir, "source/main.brs", "a");
    push();
    let { code, out } = cut(dir, "--yes");
    assert.notEqual(code, 0);
    assert.match(out, /says 7\.2\.2, below the released 8\.0\.1/);
    commit(dir, "manifest", MANIFEST.replace("major_version=7", "major_version=8"));
    push();
    ({ code, out } = cut(dir));
    assert.equal(code, 0, out);
    assert.match(out, /^8\.2\.3 is ready: v8\.2\.3\n/);
  }));
