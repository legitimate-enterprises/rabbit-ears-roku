import { test } from "node:test";
import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { join } from "node:path";

const root = new URL("..", import.meta.url).pathname;
const read = (f) => readFileSync(join(root, f), "utf8");
const body = (text, name) => text.match(new RegExp(`^sub ${name}\\([\\s\\S]*?^end sub`, "m"))?.[0] ?? "";

// A Shuffle's queue has no playlist, so the server's Up next knows nothing of it.
test("a shuffled queue's end follows the queue and never asks getUpNext", () => {
  const ask = body(read("components/views/PlayerView.brs"), "askUpNext");
  assert.match(ask, /if m\.shuffle\s+offerUpNext\(libraryQueueNext\(m\.queue\)\)\s+return\s+end if[\s\S]*getUpNext/);
});

// One countdown, so the system auto-play setting is honored in one place.
test("a shuffled Up next goes through the same card and countdown as the server's", () => {
  const player = read("components/views/PlayerView.brs");
  assert.match(body(player, "onUpNext"), /offerUpNext\(/);
  assert.match(body(player, "offerUpNext"), /m\.countdown = timer\(/);
});

test("Next in a shuffled queue plays its next row from the start", () => {
  const leave = body(read("components/views/PlayerView.brs"), "leave");
  assert.match(leave, /if target = "next" and m\.shuffle\s+n\.Append\(libraryQueueNext\(m\.queue\)\)/);
  assert.match(body(read("components/views/PlayerView.brs"), "onStarted"), /m\.shuffle then m\.info\.nextId = invalid/);
});

test("show, season and collection shuffle their whole scope into the player", () => {
  assert.match(read("components/common/details.brs"), /libraryQueueNext\(libraryShuffle\(items, series, libraryDraw\)\)/);
  assert.match(read("components/views/DetailsView.brs"), /id = "shuffle"[\s\S]*shuffle\(m\.episodes, item\)/);
  assert.match(read("components/views/SeasonView.brs"), /m\.current = "shuffle"[\s\S]*shuffle\(m\.episodes, m\.d\.show\)/);
  const collection = read("components/views/CollectionView.brs");
  assert.match(collection, /"rest", \{ op: "listCollectionMovies"/);
  assert.match(collection, /libraryQueueNext\(libraryShuffle\(r\.data, invalid, libraryDraw\)\)/);
  assert.doesNotMatch(collection, /"Play"/, "collections get Shuffle only");
});
