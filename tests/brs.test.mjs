// Runs every tests/*_test.brs under the brs interpreter with the pure
// libraries in components/lib. brs exits 0 even on a runtime error and only
// abandons the sub that raised it, so a run passes only when it reaches the
// RAN line with no FAIL line and no located error on stderr.
import { test } from "node:test";
import assert from "node:assert/strict";
import { spawnSync } from "node:child_process";
import { mkdirSync, readdirSync, readFileSync, writeFileSync } from "node:fs";
import { join } from "node:path";

const root = new URL("..", import.meta.url).pathname;
const lib = readdirSync(join(root, "components/lib")).map((f) => join(root, "components/lib", f));
const out = join(root, "build/tests");
mkdirSync(out, { recursive: true });

for (const file of readdirSync(join(root, "tests")).filter((f) => f.endsWith("_test.brs"))) {
  test(file, () => {
    const source = join(root, "tests", file);
    const names = [...readFileSync(source, "utf8").matchAll(/^sub (test\w+)\(\)/gim)].map((m) => m[1]);
    assert.ok(names.length, "no test subs");
    const main = join(out, file.replace(/\.brs$/, "_main.brs"));
    writeFileSync(
      main,
      "sub Main()\n" +
        names.map((n) => `    GetGlobalAA().test = "${n}"\n    ${n}()\n`).join("") +
        `    print "RAN ${names.length}"\nend sub\n`,
    );
    const run = spawnSync(join(root, "node_modules/.bin/brs"), [...lib, join(root, "tests/assert.brs"), source, main], {
      encoding: "utf8",
      // brs loads every component under its working directory; this one has none.
      cwd: out,
      // Local times in the tests are New York's, whatever the machine's zone.
      env: { ...process.env, TZ: "America/New_York" },
    });
    const text = run.stdout;
    const failures = text.split("\n").filter((l) => l.startsWith("FAIL"));
    assert.deepEqual(failures, [], text);
    // A runtime error names its file and position, as bif.brs(12,4-10).
    const errors = run.stderr.split("\n").filter((l) => /\.brs\(\d+,\d+/.test(l));
    assert.deepEqual(errors, [], run.stderr);
    assert.match(text, new RegExp(`^RAN ${names.length}$`, "m"), text);
  });
}
