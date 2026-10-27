// Runs supabase/migrations + seed in PGlite, then every supabase/tests/*.test.sql case.
// Each case ("-- test: <name>") runs in its own transaction after _fixture.sql and is rolled back.
import { PGlite } from '@electric-sql/pglite';
import { readFileSync, readdirSync } from 'node:fs';
import { join, dirname } from 'node:path';
import { fileURLToPath } from 'node:url';

const here = dirname(fileURLToPath(import.meta.url));
const supabaseDir = join(here, '..', '..', 'supabase');
const read = (p) => readFileSync(p, 'utf8');

const db = await PGlite.create();

async function runFile(label, sql) {
  try {
    await db.exec(sql);
  } catch (err) {
    console.error(`\nFAILED while loading ${label}:\n  ${err.message}`);
    process.exit(1);
  }
}

await runFile('supabase_stub.sql', read(join(here, 'supabase_stub.sql')));
const migrationsDir = join(supabaseDir, 'migrations');
for (const f of readdirSync(migrationsDir).filter((f) => f.endsWith('.sql')).sort()) {
  await runFile(`migrations/${f}`, read(join(migrationsDir, f)));
}
await runFile('seed.sql', read(join(supabaseDir, 'seed.sql')));

const testsDir = join(supabaseDir, 'tests');
await runFile('tests/_helpers.sql', read(join(testsDir, '_helpers.sql')));
const fixture = read(join(testsDir, '_fixture.sql'));

const filter = process.argv[2];
let passed = 0;
const failures = [];

for (const f of readdirSync(testsDir).filter((f) => f.endsWith('.test.sql')).sort()) {
  const parts = read(join(testsDir, f)).split(/^-- test: (.+)$/m);
  for (let i = 1; i < parts.length; i += 2) {
    const name = `${f} › ${parts[i].trim()}`;
    if (filter && !name.includes(filter)) continue;
    try {
      await db.exec('begin');
      await db.exec(fixture);
      await db.exec(parts[i + 1]);
      passed++;
      console.log(`  ok    ${name}`);
    } catch (err) {
      failures.push(name);
      console.log(`  FAIL  ${name}\n        ${err.message}`);
    } finally {
      await db.exec('rollback');
    }
  }
}

console.log(`\n${passed} passed, ${failures.length} failed`);
process.exit(failures.length ? 1 : 0);
