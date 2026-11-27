import { test } from "node:test";
import assert from "node:assert/strict";
import { readdirSync, readFileSync } from "node:fs";
import { join } from "node:path";

const root = new URL("..", import.meta.url).pathname;

test("no view writes the product's name where the server's belongs", () => {
  const dir = join(root, "components/views");
  for (const file of readdirSync(dir).filter((f) => f.endsWith(".brs"))) {
    const text = readFileSync(join(dir, file), "utf8");
    assert.doesNotMatch(text, /uiLabel\([^,]+, "(Sign in to )?Rabbit Ears"/, file);
  }
});
