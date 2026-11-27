import { test } from "node:test";
import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { join } from "node:path";

const root = new URL("..", import.meta.url).pathname;
const read = (f) => readFileSync(join(root, f), "utf8");

test("a collection tile and the collection view mark a hand order, drawn from order.png", () => {
  assert.match(read("components/views/GridView.brs"), /ordered: collectionOrdered\(x\)/);
  assert.match(read("components/widgets/TileItem.brs"), /c\.ordered[\s\S]*"order\.png"/);
  assert.match(read("components/views/CollectionView.brs"), /collectionOrdered\(c\)[\s\S]*"In your order"[\s\S]*"order"/);
});

// The server lists a collection's movies in its order, release or hand-made.
test("the collection view keeps the movies in the order they arrive", () => {
  assert.doesNotMatch(read("components/views/CollectionView.brs"), /\.sort(by)?\(/i);
});
