// Draws every image the package ships from the palette and the brand mark's
// geometry: store icons, splash screens, the brand mark, and white 9-patch
// shapes that Posters tint with blendColor.
import { mkdirSync, writeFileSync } from "node:fs";
import { join } from "node:path";
import { crc32, deflateSync } from "node:zlib";

const GROUND = [0x1c, 0x1c, 0x1e];
const ACCENT = [0xf2, 0xb3, 0x3d];
const WHITE = [0xff, 0xff, 0xff];

// Signed distances, negative inside.
const box = (x, y, cx, cy, hx, hy, r) => {
  const qx = Math.abs(x - cx) - (hx - r);
  const qy = Math.abs(y - cy) - (hy - r);
  return Math.hypot(Math.max(qx, 0), Math.max(qy, 0)) + Math.min(Math.max(qx, qy), 0) - r;
};
const segment = (x, y, ax, ay, bx, by, half) => {
  const t = Math.max(0, Math.min(1, ((x - ax) * (bx - ax) + (y - ay) * (by - ay)) / ((bx - ax) ** 2 + (by - ay) ** 2)));
  return Math.hypot(x - ax - t * (bx - ax), y - ay - t * (by - ay)) - half;
};
const cover = (d) => Math.max(0, Math.min(1, 0.5 - d));

// The brand mark on its 24-unit grid: two antennas over a rounded set body.
function glyph(x, y) {
  const body = Math.abs(box(x, y, 12, 17, 8, 4, 2)) - 1;
  return Math.min(segment(x, y, 12, 13, 6, 3, 1), segment(x, y, 12, 13, 18, 3, 1), body);
}

function image(w, h, paint) {
  const px = Buffer.alloc(w * h * 4);
  for (let y = 0; y < h; y++)
    for (let x = 0; x < w; x++) {
      const [rgb, a] = paint(x + 0.5, y + 0.5);
      px.set([...rgb, Math.round(a * 255)], (y * w + x) * 4);
    }
  return { w, h, px };
}

// A glyph of `size` pixels centered on a ground-colored canvas.
const card = (w, h, size) => {
  const s = size / 24;
  return image(w, h, (x, y) => {
    const a = cover(glyph((x - w / 2) / s + 12, (y - h / 2) / s + 12) * s);
    return [GROUND.map((g, i) => Math.round(g + (ACCENT[i] - g) * a)), 1];
  });
};

// A white shape inside a 1-pixel 9-patch border whose black top and left
// marks make the middle row and column stretch.
function ninePatch(size, alpha) {
  const inner = image(size, size, (x, y) => [WHITE, alpha(x, y)]);
  const w = size + 2;
  const mid = Math.floor(size / 2) + 1;
  return image(w, w, (x, y) => {
    const [ix, iy] = [Math.floor(x), Math.floor(y)];
    if (iy === 0 || ix === 0 || iy === w - 1 || ix === w - 1)
      return [[0, 0, 0], (iy === 0 && ix === mid) || (ix === 0 && iy === mid) ? 1 : 0];
    return [WHITE, inner.px[((iy - 1) * size + ix - 1) * 4 + 3] / 255];
  });
}
// An unpressed chip: a 2-pixel line around a pill.
const outline = (r) => {
  const c = r + 0.5;
  return ninePatch(2 * r + 1, (x, y) => cover(box(x, y, c, c, c, c, r)) - cover(box(x, y, c, c, c - 2, c - 2, r - 2)));
};
const fill = (r) => ninePatch(2 * r + 1, (x, y) => cover(box(x, y, r + 0.5, r + 0.5, r + 0.5, r + 0.5, r)));
// The focus ring: 5 pixels wide, 5 pixels off a shape of radius 14, so the
// shape sits 10 pixels inside the ring's outer edge.
const ring = () => {
  const r = 24;
  const c = r + 0.5;
  return ninePatch(2 * r + 1, (x, y) => cover(box(x, y, c, c, c, c, r)) - cover(box(x, y, c, c, c - 5, c - 5, r - 5)));
};
// Icons on a 24-unit grid, stroked 2.5 units like the boards' glyphs.
const icon = (size, dist) => {
  const s = size / 24;
  return image(size, size, (x, y) => [WHITE, cover(dist(x / s, y / s) * s)]);
};
// A filled convex shape from its corners, wound like the play glyph.
const convex = (points) => (x, y) => {
  const edges = points.map(([ax, ay], i) => [ax, ay, ...points[(i + 1) % points.length]]);
  const d = Math.min(...edges.map(([ax, ay, bx, by]) => segment(x, y, ax, ay, bx, by, 0)));
  const inside = edges.every(([ax, ay, bx, by]) => (bx - ax) * (y - ay) - (by - ay) * (x - ax) <= 0);
  return inside ? -d : d;
};
// The play glyph: M6 4v16l14-8z.
const triangle = convex([[6, 4], [6, 20], [20, 12]]);
// A five-pointed star's corners, outer and inner in turn from the top.
const starCorners = Array.from({ length: 10 }, (_, i) => {
  const r = i % 2 ? 4.2 : 10;
  const a = -Math.PI / 2 + (i * Math.PI) / 5;
  return [12 + r * Math.cos(a), 12.8 + r * Math.sin(a)];
});
const starEdges = starCorners.map(([ax, ay], i) => [ax, ay, ...starCorners[(i + 1) % starCorners.length]]);
// The filled star: inside by the even-odd rule, as the star is not convex.
const starFill = (x, y) => {
  const d = Math.min(...starEdges.map(([ax, ay, bx, by]) => segment(x, y, ax, ay, bx, by, 0)));
  const inside = starEdges.reduce((odd, [ax, ay, bx, by]) => ((ay > y) !== (by > y) && x < ax + ((y - ay) * (bx - ax)) / (by - ay) ? !odd : odd), false);
  return inside ? -d : d;
};
// Lines 2 units wide through each pair of points.
const lines = (x, y, pairs) => Math.min(...pairs.map(([ax, ay, bx, by]) => segment(x, y, ax, ay, bx, by, 1)));
const disc = (d, width) =>
  image(d, d, (x, y) => {
    const dist = Math.hypot(x - d / 2, y - d / 2) - d / 2;
    return [WHITE, width ? cover(dist) - cover(dist + width) : cover(dist)];
  });

function png({ w, h, px }) {
  const chunk = (type, data) => {
    const len = Buffer.alloc(4);
    len.writeUInt32BE(data.length);
    const body = Buffer.concat([Buffer.from(type), data]);
    const crc = Buffer.alloc(4);
    crc.writeUInt32BE(crc32(body));
    return Buffer.concat([len, body, crc]);
  };
  const header = Buffer.alloc(13);
  header.writeUInt32BE(w, 0);
  header.writeUInt32BE(h, 4);
  header.set([8, 6, 0, 0, 0], 8);
  const rows = Buffer.alloc((w * 4 + 1) * h);
  for (let y = 0; y < h; y++) px.copy(rows, y * (w * 4 + 1) + 1, y * w * 4, (y + 1) * w * 4);
  return Buffer.concat([
    Buffer.from([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a]),
    chunk("IHDR", header),
    chunk("IDAT", deflateSync(rows)),
    chunk("IEND", Buffer.alloc(0)),
  ]);
}

// Outlines 2 units wide on the 24-unit grid, one per kind of tile.
const stroke = (d) => Math.abs(d) - 1;
const arc = (x, y, cx, cy, r) => stroke(Math.hypot(x - cx, y - cy) - r);
const tv = (x, y) => Math.min(stroke(box(x, y, 12, 14, 9, 6, 2)), lines(x, y, [[8, 4, 12, 8], [16, 4, 12, 8]]));
const placeholders = {
  movie: (x, y) => Math.min(stroke(box(x, y, 12, 12, 9, 8, 2)), lines(x, y, [[7, 4, 7, 20], [17, 4, 17, 20], [3, 9, 7, 9], [3, 15, 7, 15], [17, 9, 21, 9], [17, 15, 21, 15]])),
  show: tv,
  album: (x, y) => Math.min(arc(x, y, 12, 12, 9), Math.hypot(x - 12, y - 12) - 2),
  artist: (x, y) => Math.min(stroke(box(x, y, 12, 8, 3, 5, 3)), y > 11 ? arc(x, y, 12, 11, 6) : 99, lines(x, y, [[12, 17, 12, 21], [8, 21, 16, 21]])),
  song: (x, y) => Math.min(Math.hypot(x - 8, y - 17) - 3.5, lines(x, y, [[11, 17, 11, 5], [11, 5, 19, 7]])),
  channel: (x, y) => Math.min(tv(x, y), convex([[10, 10], [10, 18], [16, 14]])(x, y)),
  video: (x, y) => Math.min(stroke(box(x, y, 12, 12, 9, 7, 2)), convex([[10, 9], [10, 15], [15, 12]])(x, y)),
  playlist: (x, y) => lines(x, y, [[4, 7, 20, 7], [4, 12, 20, 12], [4, 17, 14, 17]]),
  station: glyph,
  collection: (x, y) => Math.min(stroke(box(x, y, 10, 14, 7, 6, 1.5)), lines(x, y, [[6, 5, 20, 5], [20, 5, 20, 16]])),
  person: (x, y) => Math.min(arc(x, y, 12, 8, 4), y < 21 ? arc(x, y, 12, 21, 8) : 99),
};

const out = process.argv[2];
if (!out) {
  console.error("usage: node images.mjs <out dir>");
  process.exit(64);
}
mkdirSync(out, { recursive: true });
const brandSize = 104;
const files = {
  // Store sizes: channel poster and splash screen at FHD, HD and SD.
  "icon_fhd.png": card(540, 405, 220),
  "icon_hd.png": card(290, 218, 118),
  "icon_sd.png": card(246, 140, 76),
  "splash_fhd.png": card(1920, 1080, 240),
  "splash_hd.png": card(1280, 720, 160),
  "splash_sd.png": card(720, 480, 108),
  "brand.png": image(brandSize, brandSize, (x, y) => [ACCENT, cover(glyph(x / (brandSize / 24), y / (brandSize / 24)) * (brandSize / 24))]),
  "fill12.9.png": fill(12),
  "fill14.9.png": fill(14),
  "fill16.9.png": fill(16),
  "fill28.9.png": fill(28),
  "outline14.9.png": outline(14),
  "outline28.9.png": outline(28),
  "ring.9.png": ring(),
  "disc.png": disc(200),
  "play.png": icon(52, triangle),
  "check.png": icon(52, (x, y) => Math.min(segment(x, y, 5, 12, 10, 17, 1.25), segment(x, y, 10, 17, 19, 7, 1.25))),
  "chevron.png": icon(44, (x, y) => Math.min(segment(x, y, 6, 9, 12, 15, 1.25), segment(x, y, 12, 15, 18, 9, 1.25))),
  "lock.png": icon(64, (x, y) =>
    Math.min(box(x, y, 12, 16, 7, 5, 2), Math.abs(Math.hypot(x - 12, y - 7) - 4) - 1.1 + (y > 11 ? 99 : 0), segment(x, y, 8, 7, 8, 11, 1.1), segment(x, y, 16, 7, 16, 11, 1.1)),
  ),
  "subtitles.png": icon(52, (x, y) =>
    Math.min(Math.abs(box(x, y, 12, 12, 9, 7, 2)) - 1, lines(x, y, [[7, 13, 13, 13], [15, 13, 17, 13], [7, 16, 9, 16], [11, 16, 17, 16]])),
  ),
  "next.png": icon(52, (x, y) => Math.min(convex([[4, 5], [4, 19], [15, 12]])(x, y), box(x, y, 17, 12, 1, 7, 0))),
  "backspace.png": icon(72, (x, y) =>
    lines(x, y, [[9, 5, 20, 5], [20, 5, 20, 19], [20, 19, 9, 19], [9, 19, 3, 12], [3, 12, 9, 5], [12, 9, 17, 15], [17, 9, 12, 15]]),
  ),
  // The playing song's three bars, shortest last.
  "bars.png": icon(52, (x, y) => Math.min(segment(x, y, 5, 12, 5, 20, 1.5), segment(x, y, 12, 6, 12, 20, 1.5), segment(x, y, 19, 15, 19, 20, 1.5))),
  "shuffle.png": icon(52, (x, y) =>
    lines(x, y, [[2, 18, 6, 18], [6, 18, 14, 6], [14, 6, 21, 6], [18, 3, 21, 6], [21, 6, 18, 9], [2, 6, 6, 6], [6, 6, 8.5, 9.5], [21, 18, 14, 18], [14, 18, 11.5, 14.5], [18, 15, 21, 18], [21, 18, 18, 21]]),
  ),
  "repeat.png": icon(52, (x, y) =>
    lines(x, y, [[17, 3, 20, 6], [20, 6, 17, 9], [4, 11, 4, 9], [4, 9, 7, 6], [7, 6, 20, 6], [7, 21, 4, 18], [4, 18, 7, 15], [20, 13, 20, 15], [20, 15, 17, 18], [17, 18, 4, 18]]),
  ),
  // Watch together: two people, the nearer one whole.
  "users.png": icon(52, (x, y) =>
    Math.min(
      Math.abs(Math.hypot(x - 9, y - 7) - 4) - 1.1,
      y <= 21 ? Math.abs(Math.hypot(x - 9, y - 21) - 6.5) - 1.1 : 99,
      x >= 16 ? Math.abs(Math.hypot(x - 16, y - 7) - 4) - 1.1 : 99,
      lines(x, y, [[19, 15.5, 22, 18.5], [22, 18.5, 22, 21]]),
    ),
  ),
  // A hand-made order: one arrow up, one down.
  "order.png": icon(52, (x, y) =>
    lines(x, y, [[8, 20, 8, 4], [4, 8, 8, 4], [8, 4, 12, 8], [16, 4, 16, 20], [12, 16, 16, 20], [16, 20, 20, 16]]),
  ),
  // Favorite off and on.
  "star.png": icon(52, (x, y) => Math.min(...starEdges.map(([ax, ay, bx, by]) => segment(x, y, ax, ay, bx, by, 1.1)))),
  "star-fill.png": icon(52, starFill),
  "pause.png": icon(52, (x, y) => Math.min(box(x, y, 8, 12, 2, 7, 0.5), box(x, y, 16, 12, 2, 7, 0.5))),
  "stop.png": icon(52, (x, y) => box(x, y, 12, 12, 6, 6, 1)),
  // What a tile shows over its flat block until its artwork arrives, one per kind.
  ...Object.fromEntries(Object.entries(placeholders).map(([kind, dist]) => [`ph-${kind}.png`, icon(64, dist)])),
  // A vertical fade from clear to the ground color, stretched over artwork.
  "fade.png": image(1, 256, (x, y) => [GROUND, y / 256]),
  "disc-ring.png": disc(220, 5),
  // One soft round spot, white with an alpha falloff, that an occasion's screen scales up and
  // tints with blendColor, three of them, for its wash.
  "spot.png": image(512, 512, (x, y) => {
    const t = Math.max(0, 1 - Math.hypot(x - 256, y - 256) / 256);
    return [WHITE, t * t * (3 - 2 * t)];
  }),
};
for (const [name, img] of Object.entries(files)) writeFileSync(join(out, name), png(img));
