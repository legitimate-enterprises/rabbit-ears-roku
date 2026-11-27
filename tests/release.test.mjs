// Runs scripts/release.sh against a fake Roku in developer mode: a server
// that demands digest credentials and answers the installer, the packager
// and the package download with the page text a device gives. The script
// runs from a copy beside a stub build and a stub gh, so nothing here
// touches build/ or reaches GitHub.
import { test } from "node:test";
import assert from "node:assert/strict";
import { spawn } from "node:child_process";
import { createHash } from "node:crypto";
import { createServer } from "node:http";
import { chmodSync, copyFileSync, existsSync, mkdirSync, mkdtempSync, readFileSync, rmSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";

// Each holds a character curl's config syntax escapes or that -F reads as a file.
const DEV_PASSWORD = 'dev "pass\\word';
const SIGNING_PASSWORD = 'sign\\n"@<key';

const md5 = (s) => createHash("md5").update(s).digest("hex");

function authorized(req) {
  const f = Object.fromEntries(
    [...(req.headers.authorization ?? "").matchAll(/(\w+)="?([^",]*)"?/g)].map((m) => [m[1], m[2]]),
  );
  const ha1 = md5(`rokudev:rokudev:${DEV_PASSWORD}`);
  const ha2 = md5(`${req.method}:${f.uri}`);
  return f.response === md5(`${ha1}:${f.nonce}:${f.nc}:${f.cnonce}:${f.qop}:${ha2}`);
}

const field = (body, name) =>
  new RegExp(`name="${name}"[^\\r\\n]*\\r\\n(?:[^\\r\\n]+\\r\\n)*\\r\\n([\\s\\S]*?)\\r\\n--`).exec(body)?.[1];

const INSTALLED = '<font color="red">Application Received: 3 bytes stored.</font><font color="red">Install Success.</font>';
const PACKAGED =
  '<div style="display:none"><a href="pkgs//Pabc.pkg">Pabc.pkg</a></div>' +
  `<script>var params = JSON.parse('{"messages":null,"packages":[{"appType":"channel","pkgPath":"pkgs/sdcard0/Pabc.pkg"}]}');</script>`;

// fakeRoku(pages): a device whose installer and packager answer with pages.install
// and pages.package; requests lists what it accepted.
async function fakeRoku(pages = {}) {
  const requests = [];
  let asleep = pages.asleep ?? 0;
  const server = createServer((req, res) => {
    // A TV waking from standby drops its first connections.
    if (asleep-- > 0) return void req.socket.destroy();
    let body = "";
    req.setEncoding("latin1");
    req.on("data", (chunk) => (body += chunk));
    req.on("end", () => {
      if (!authorized(req)) {
        res.writeHead(401, { "WWW-Authenticate": 'Digest realm="rokudev", nonce="n0nce", qop="auth"' }).end();
        return;
      }
      const submit = field(body, "mysubmit");
      requests.push({ request: `${req.method} ${req.url} ${submit ?? ""}`.trim(), body });
      if (req.url === "/plugin_install") res.end(submit === "Install" ? (pages.install ?? INSTALLED) : "");
      else if (req.url === "/plugin_package")
        res.end(
          field(body, "passwd") === SIGNING_PASSWORD
            ? (pages.package ?? PACKAGED)
            : '<font color="red">Failed: Invalid Password.\n</font>',
        );
      else if (req.method === "GET" && /\/P(abc|new)\.pkg$/.test(req.url)) res.end(pages.pkg ?? "signed package");
      else res.writeHead(404).end();
    });
  });
  await new Promise((resolve) => server.listen(0, "127.0.0.1", resolve));
  return { host: `127.0.0.1:${server.address().port}`, requests, close: () => server.close() };
}

function workspace() {
  const dir = mkdtempSync(join(tmpdir(), "roku-release-"));
  mkdirSync(join(dir, "scripts"));
  mkdirSync(join(dir, "bin"));
  copyFileSync(new URL("../scripts/release.sh", import.meta.url), join(dir, "scripts/release.sh"));
  chmodSync(join(dir, "scripts/release.sh"), 0o755);
  writeFileSync(join(dir, "manifest"), "title=Rabbit Ears\nmajor_version=7\nminor_version=2\nbuild_version=5\n");
  writeFileSync(join(dir, "Makefile"), "build:\n\tmkdir -p build && printf zip > build/rabbit-ears.zip\n");
  // A release that exists already refuses create, as gh does.
  writeFileSync(join(dir, "bin/gh"), '#!/bin/sh\necho "$*" >> gh.log\n[ "$2" != create ] || [ -z "$GH_EXISTS" ]\n');
  chmodSync(join(dir, "bin/gh"), 0o755);
  // Records each curl command line, which any process listing on the runner shows.
  writeFileSync(join(dir, "bin/curl"), '#!/bin/sh\nprintf \'%s\\n\' "$*" >> curl.log\nexec /usr/bin/curl "$@"\n');
  chmodSync(join(dir, "bin/curl"), 0o755);
  return dir;
}

function release(dir, host, env = {}, tag = "v7.2.5") {
  const child = spawn(join(dir, "scripts/release.sh"), [tag], {
    env: {
      PATH: `${join(dir, "bin")}:${process.env.PATH}`,
      TMPDIR: tmpdir(),
      CI: "true",
      ROKU_HOST: host,
      ROKU_PASSWORD: DEV_PASSWORD,
      ROKU_SIGNING_PASSWORD: SIGNING_PASSWORD,
      GH_TOKEN: "token",
      ...env,
    },
  });
  let out = "";
  child.stdout.on("data", (d) => (out += d));
  child.stderr.on("data", (d) => (out += d));
  return new Promise((resolve) => child.on("close", (code) => resolve({ code, out })));
}

const read = (dir, file) => (existsSync(join(dir, file)) ? readFileSync(join(dir, file), "utf8") : undefined);

async function withRoku(pages, run) {
  const roku = await fakeRoku(pages);
  const dir = workspace();
  try {
    await run(roku, dir);
  } finally {
    roku.close();
    rmSync(dir, { recursive: true, force: true });
  }
}

test("signs the sideloaded build and attaches the package to the tag's release", () =>
  withRoku({}, async (roku, dir) => {
    const { code, out } = await release(dir, roku.host);
    assert.equal(code, 0, out);
    assert.deepEqual(
      roku.requests.map((r) => r.request),
      [
        "POST /plugin_install Delete",
        "POST /plugin_install Install",
        "POST /plugin_package Package",
        "GET /pkgs/sdcard0/Pabc.pkg",
      ],
    );
    assert.equal(field(roku.requests[1].body, "archive"), "zip");
    assert.equal(field(roku.requests[2].body, "app_name"), "Rabbit Ears/7.2.5");
    assert.equal(read(dir, "build/rabbit-ears.pkg"), "signed package");
    assert.match(read(dir, "gh.log"), /^release create v7\.2\.5 build\/rabbit-ears\.pkg .*--verify-tag/);
    assert.match(read(dir, "curl.log"), /plugin_package/);
    for (const text of [out, read(dir, "curl.log")]) {
      assert.ok(!text.includes(DEV_PASSWORD) && !text.includes(SIGNING_PASSWORD), text);
    }
  }));

test("a Roku still waking from standby is waited for", () =>
  withRoku({ asleep: 2 }, async (roku, dir) => {
    const { code, out } = await release(dir, roku.host, { ROKU_WAKE_PAUSE: "0" });
    assert.equal(code, 0, out);
    assert.match(read(dir, "gh.log"), /release create v7\.2\.5 /);
  }));

test("a missing secret fails before the build, naming the secret", () =>
  withRoku({}, async (roku, dir) => {
    const { code, out } = await release(dir, roku.host, { ROKU_SIGNING_PASSWORD: "" });
    assert.notEqual(code, 0);
    assert.match(out, /ROKU_SIGNING_PASSWORD is not set/);
    assert.equal(read(dir, "build/rabbit-ears.zip"), undefined);
    assert.deepEqual(roku.requests, []);
  }));

test("a tag the manifest does not state fails before the build", async () => {
  for (const tag of ["v7.2.6", "v7.2", "roku-v7", "7.2.5"]) {
    await withRoku({}, async (roku, dir) => {
      const { code, out } = await release(dir, roku.host, {}, tag);
      assert.notEqual(code, 0, tag);
      assert.match(out, new RegExp(`${tag} is not v7\\.2\\.5, the version manifest states`), tag);
      assert.equal(read(dir, "build/rabbit-ears.zip"), undefined);
    });
  }
});

test("a wrong developer password names ROKU_PASSWORD", () =>
  withRoku({}, async (roku, dir) => {
    const { code, out } = await release(dir, roku.host, { ROKU_PASSWORD: "wrong" });
    assert.notEqual(code, 0);
    assert.match(out, /the Roku refused ROKU_PASSWORD/);
    assert.deepEqual(roku.requests, []);
  }));

test("a failed sideload packages nothing", () =>
  withRoku({ install: '<font color="red">Install Failure: Compilation Failed.</font>' }, async (roku, dir) => {
    const { code, out } = await release(dir, roku.host);
    assert.notEqual(code, 0);
    assert.match(out, /sideloading failed: Install Failure: Compilation Failed\./);
    assert.ok(!roku.requests.some((r) => r.request.includes("plugin_package")));
  }));

test("a signing password the device's key refuses publishes nothing", () =>
  withRoku({}, async (roku, dir) => {
    const { code, out } = await release(dir, roku.host, { ROKU_SIGNING_PASSWORD: "wrong" });
    assert.notEqual(code, 0);
    assert.match(out, /packaging failed: Failed: Invalid Password\./);
    assert.equal(read(dir, "build/rabbit-ears.pkg"), undefined);
    assert.equal(read(dir, "gh.log"), undefined);
  }));

test("a packager page that only links the package still yields it", () =>
  withRoku({ package: '<a href="pkgs//Pabc.pkg">Pabc.pkg</a>' }, async (roku, dir) => {
    const { code, out } = await release(dir, roku.host);
    assert.equal(code, 0, out);
    assert.equal(roku.requests.at(-1).request, "GET /pkgs//Pabc.pkg");
  }));

test("a re-run replaces the package on the release its first attempt made", () =>
  withRoku({}, async (roku, dir) => {
    const { code, out } = await release(dir, roku.host, { GH_EXISTS: "1" });
    assert.equal(code, 0, out);
    assert.match(read(dir, "gh.log"), /\nrelease upload v7\.2\.5 build\/rabbit-ears\.pkg --clobber\n$/);
  }));

test("a release outside CI is refused before anything else", () =>
  withRoku({}, async (roku, dir) => {
    const { code, out } = await release(dir, roku.host, { CI: "" });
    assert.notEqual(code, 0);
    assert.match(out, /releases are produced by CI only/);
    assert.equal(read(dir, "build/rabbit-ears.zip"), undefined);
    assert.deepEqual(roku.requests, []);
  }));

test("a tag is compared to the manifest's version as text, not a pattern", () =>
  withRoku({}, async (roku, dir) => {
    const { code, out } = await release(dir, roku.host, {}, "v7x2x5");
    assert.notEqual(code, 0);
    assert.match(out, /v7x2x5 is not v7\.2\.5, the version manifest states/);
    assert.equal(read(dir, "build/rabbit-ears.zip"), undefined);
  }));

test("an empty package download publishes nothing", () =>
  withRoku({ pkg: "" }, async (roku, dir) => {
    const { code, out } = await release(dir, roku.host);
    assert.notEqual(code, 0);
    assert.match(out, /downloading the package failed/);
    assert.equal(read(dir, "build/rabbit-ears.pkg"), undefined);
    assert.equal(read(dir, "gh.log"), undefined);
  }));

test("a packager page listing several packages yields the first", () =>
  withRoku(
    {
      package:
        '<a href="pkgs//Pnew.pkg">Pnew.pkg</a><a href="pkgs//Pold.pkg">Pold.pkg</a>' +
        '<script>var params = JSON.parse(\'{"packages":[{"pkgPath":"pkgs/sdcard0/Pnew.pkg"},{"pkgPath":"pkgs/sdcard0/Pold.pkg"}]}\');</script>',
    },
    async (roku, dir) => {
      const { code, out } = await release(dir, roku.host);
      assert.equal(code, 0, out);
      assert.equal(roku.requests.at(-1).request, "GET /pkgs/sdcard0/Pnew.pkg");
    },
  ));

test("a link-only packager page listing several packages yields the first", () =>
  withRoku({ package: '<a href="pkgs//Pnew.pkg">Pnew.pkg</a><a href="pkgs//Pold.pkg">Pold.pkg</a>' }, async (roku, dir) => {
    const { code, out } = await release(dir, roku.host);
    assert.equal(code, 0, out);
    assert.equal(roku.requests.at(-1).request, "GET /pkgs//Pnew.pkg");
  }));
