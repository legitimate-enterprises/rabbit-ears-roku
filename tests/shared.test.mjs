import { test } from "node:test";
import assert from "node:assert/strict";
import { readdirSync, readFileSync } from "node:fs";
import { join } from "node:path";

const root = new URL("..", import.meta.url).pathname;

// Every view that makes a playlist's tile captions it with playlistCaption(x).
test("every playlist tile tells TileItem whether it is shared", () => {
  const dir = join(root, "components/views");
  const views = readdirSync(dir)
    .filter((f) => f.endsWith(".brs"))
    .filter((f) => readFileSync(join(dir, f), "utf8").includes("playlistCaption(x)"));
  assert.ok(views.length >= 2, "the views that make playlist tiles");
  for (const file of views) assert.match(readFileSync(join(dir, file), "utf8"), /shared: [^,}]*x\.shared/, file);
});

test("TileItem draws the Shared badge from users.png", () => {
  const text = readFileSync(join(root, "components/widgets/TileItem.brs"), "utf8");
  assert.match(text, /c\.shared[\s\S]*"users\.png"/);
});
