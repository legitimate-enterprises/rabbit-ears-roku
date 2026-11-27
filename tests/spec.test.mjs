// specOperations relies on the layout the spec's linter fixes: paths at two
// spaces of indent, methods at four.
import { test } from "node:test";
import assert from "node:assert/strict";
import { readFileSync } from "node:fs";

const read = (p) => readFileSync(new URL(p, import.meta.url), "utf8");

function specOperations(yaml) {
  const ops = new Set();
  let path;
  for (const line of yaml.split("\n")) {
    const p = /^  (\/\S*):\s*$/.exec(line);
    if (p) path = p[1];
    else if (/^\S/.test(line)) path = undefined;
    const m = /^    (get|put|post|delete|patch):\s*$/.exec(line);
    if (path && m) ops.add(`${m[1].toUpperCase()} ${path}`);
  }
  return ops;
}

test("the API client calls only operations in the spec", () => {
  const spec = specOperations(read("../openapi.yaml"));
  assert.ok(spec.has("GET /items/{itemId}"), "spec parser found no operations");
  const client = [...read("../components/lib/api.brs").matchAll(/^\s+(\w+): \["(\w+)", "([^"]+)"\]$/gm)];
  assert.ok(client.length > 20, "found no operations in apiOperations()");
  const missing = client.map(([, name, method, path]) => [name, `${method} ${path}`]).filter(([, op]) => !spec.has(op));
  assert.deepEqual(missing, []);
});


// A Roku lowercases a literal's unquoted keys, so apiRequest spells each
// name it sends from apiNames(), which must hold every camelCase name the
// spec gives a property or parameter.
test("apiNames() holds every camelCase name in the spec", () => {
  const yaml = read("../openapi.yaml");
  const spec = new Set([
    ...[...yaml.matchAll(/^\s+([a-z][a-z0-9]*[A-Z]\w*):/gm)].map((m) => m[1]),
    ...[...yaml.matchAll(/\bname:\s*([a-z][a-z0-9]*[A-Z]\w*)/g)].map((m) => m[1]),
  ]);
  const listed = /function apiNames\(\)[\s\S]*?names = \[([\s\S]*?)\]/.exec(read("../components/lib/api.brs"));
  assert.ok(listed, "found no apiNames() list");
  const names = new Set([...listed[1].matchAll(/"(\w+)"/g)].map((m) => m[1]));
  assert.deepEqual([...spec].filter((n) => !names.has(n)).sort(), []);
});
