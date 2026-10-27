// Backend explorer: the real migrations + seed + test fixture in PGlite, behind a tiny local
// web UI. Lets you act as crew, dispatcher or admin and watch the database rules respond.
// Usage: node explorer.mjs  →  http://localhost:4321
import { PGlite } from '@electric-sql/pglite';
import http from 'node:http';
import { readFileSync, readdirSync } from 'node:fs';
import { join, dirname } from 'node:path';
import { fileURLToPath } from 'node:url';

const here = dirname(fileURLToPath(import.meta.url));
const supabaseDir = join(here, '..', '..', 'supabase');
const read = (p) => readFileSync(p, 'utf8');
const port = Number(process.env.PORT || 4321);

async function freshDb() {
  const db = await PGlite.create();
  await db.exec(read(join(here, 'supabase_stub.sql')));
  const migrations = join(supabaseDir, 'migrations');
  for (const f of readdirSync(migrations).filter((f) => f.endsWith('.sql')).sort()) {
    await db.exec(read(join(migrations, f)));
  }
  await db.exec(read(join(supabaseDir, 'seed.sql')));
  await db.exec(read(join(supabaseDir, 'tests', '_fixture.sql')));
  return db;
}

let db = await freshDb();

// PGlite is single-connection: run requests one at a time.
let queue = Promise.resolve();
const serial = (fn) => {
  const p = queue.then(fn, fn);
  queue = p.catch(() => {});
  return p;
};

// Runs SQL in its own transaction, as an app user (JWT sub) or as the system when `as` is empty.
async function run({ as, sql, params }) {
  await db.exec('begin');
  try {
    if (as) {
      await db.query(
        "select set_config('role', 'authenticated', true), set_config('request.jwt.claim.sub', $1, true)",
        [as]);
    }
    let result;
    if (params) {
      result = await db.query(sql, params);
    } else {
      const results = await db.exec(sql);
      result = results[results.length - 1];
    }
    await db.exec('commit');
    return {
      rows: result?.rows ?? [],
      fields: (result?.fields ?? []).map((f) => f.name),
      affectedRows: result?.affectedRows ?? 0,
    };
  } catch (err) {
    await db.exec('rollback');
    return { error: err.message };
  }
}

const json = (res, status, body) => {
  res.writeHead(status, { 'content-type': 'application/json' });
  res.end(JSON.stringify(body));
};

const readBody = (req) => new Promise((resolve, reject) => {
  let data = '';
  req.on('data', (c) => { data += c; });
  req.on('end', () => {
    try { resolve(data ? JSON.parse(data) : {}); } catch (e) { reject(e); }
  });
});

http.createServer(async (req, res) => {
  try {
    if (req.method === 'GET' && (req.url === '/' || req.url === '/index.html')) {
      res.writeHead(200, { 'content-type': 'text/html; charset=utf-8' });
      res.end(read(join(here, 'explorer.html')));
    } else if (req.method === 'POST' && req.url === '/api/run') {
      const body = await readBody(req);
      json(res, 200, await serial(() => run(body)));
    } else if (req.method === 'POST' && req.url === '/api/reset') {
      await serial(async () => { db = await freshDb(); });
      json(res, 200, { ok: true });
    } else {
      json(res, 404, { error: 'not found' });
    }
  } catch (err) {
    json(res, 500, { error: err.message });
  }
}).listen(port, () => console.log(`Backend explorer on http://localhost:${port}`));
