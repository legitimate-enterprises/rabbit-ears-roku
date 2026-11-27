import { test } from "node:test";
import assert from "node:assert/strict";
import { execFileSync } from "node:child_process";
import { existsSync, mkdtempSync, readFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";

const root = new URL("..", import.meta.url).pathname;

test("uiGlyph names only icons images.mjs draws", () => {
  const out = mkdtempSync(join(tmpdir(), "roku-images-"));
  execFileSync("node", [join(root, "scripts/images.mjs"), out]);
  const source = readFileSync(join(root, "components/common/ui.brs"), "utf8");
  const names = source.match(/names = \{([^}]*)\}/)?.[1] ?? "";
  const files = new Set([...names.matchAll(/:\s*"(\w+)"/g)].map((m) => m[1]));
  assert.ok(files.size >= 10, "the kinds uiGlyph maps");
  for (const file of files) assert.ok(existsSync(join(out, `ph-${file}.png`)), file);
});
