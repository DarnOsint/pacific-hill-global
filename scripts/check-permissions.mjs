#!/usr/bin/env node
/**
 * scripts/check-permissions.mjs
 *
 * The permission catalogue exists in two places, and they must not drift:
 *
 *   supabase/seed/001_permissions.sql  — the source of truth for what exists
 *   src/lib/rbac/permissions.ts        — the type-level mirror
 *
 * A key added to one and not the other fails in a bad way: in SQL, a role bundle
 * silently grants nothing; in TypeScript, a guard references a key that can never
 * be held, so the protected route 403s for everyone including the person who
 * built it. Neither is a loud failure, which is why this check exists.
 *
 * Also verified here:
 *   - every permission referenced by a role bundle exists
 *   - every permission key referenced in src/ exists
 *   - `platform.admin` is defined exactly once (it defines isSuperuser)
 *
 * Run: npm run test:rbac
 */
import { readFileSync, readdirSync, statSync } from "node:fs";
import { join, dirname } from "node:path";
import { fileURLToPath } from "node:url";

const root = join(dirname(fileURLToPath(import.meta.url)), "..");
const read = (p) => readFileSync(join(root, p), "utf8");

const errors = [];
const notes = [];

/* -------------------------------------------------------------------------- */
/* 1. Parse the SQL catalogue                                                   */
/* -------------------------------------------------------------------------- */

const seedSql = read("supabase/seed/001_permissions.sql");
const sqlPermissions = new Set();

for (const line of seedSql.split("\n")) {
  const m = line.match(/^\(\s*'([a-z0-9_.]+)'/);
  if (m) sqlPermissions.add(m[1]);
}

/* -------------------------------------------------------------------------- */
/* 2. Parse the TypeScript catalogue                                           */
/* -------------------------------------------------------------------------- */

const tsSrc = read("src/lib/rbac/permissions.ts");
const tsPermissions = new Set();

for (const m of tsSrc.matchAll(/^\s*[A-Z0-9_]+:\s*"([a-z0-9_.]+)"/gm)) {
  tsPermissions.add(m[1]);
}

/* -------------------------------------------------------------------------- */
/* 3. Compare                                                                  */
/* -------------------------------------------------------------------------- */

for (const key of sqlPermissions) {
  if (!tsPermissions.has(key)) {
    errors.push(`permission in SQL but missing from permissions.ts: ${key}`);
  }
}
for (const key of tsPermissions) {
  if (!sqlPermissions.has(key)) {
    errors.push(`permission in permissions.ts but missing from SQL: ${key}`);
  }
}

// platform.admin is load-bearing: it is the only thing that produces
// isSuperuser in guards.ts. A duplicate or rename here silently changes who can
// bypass every permission and scope check.
if (sqlPermissions.has("platform.admin") && !tsPermissions.has("platform.admin")) {
  errors.push("platform.admin must exist in both catalogues");
}

/* -------------------------------------------------------------------------- */
/* 4. Every permission key referenced anywhere in src/ must exist              */
/* -------------------------------------------------------------------------- */

function walk(dir) {
  return readdirSync(dir).flatMap((entry) => {
    const full = join(dir, entry);
    if (statSync(full).isDirectory()) return walk(full);
    return /\.(ts|tsx)$/.test(entry) ? [full] : [];
  });
}

const sourceFiles = walk(join(root, "src"));
const KNOWN_NON_PERMISSION = new Set([
  "read_only", "platform.admin",
]);

for (const file of sourceFiles) {
  const src = readFileSync(file, "utf8");
  const rel = file.replace(root + "/", "");

  // Guard call sites: requirePermission("x"), has_permission('x') in SQL strings
  for (const m of src.matchAll(/(?:has_permission|has_any_permission|currentPathGuess)\(\s*['"]([a-z0-9_.]+)['"]/g)) {
    const key = m[1];
    if (KNOWN_NON_PERMISSION.has(key)) continue;
    if (!sqlPermissions.has(key)) {
      errors.push(`${rel}: references unknown permission "${key}"`);
    }
  }
  // Array form: has_any_permission(array['a','b',...])
  for (const m of src.matchAll(/array\[([^\]]*)\]/g)) {
    for (const k of m[1].matchAll(/'([a-z0-9_.]+)'/g)) {
      if (!sqlPermissions.has(k[1])) {
        errors.push(`${rel}: references unknown permission "${k[1]}"`);
      }
    }
  }
}

/* -------------------------------------------------------------------------- */
/* 5. Same check, for permission keys hard-coded in the SQL functions           */
/* -------------------------------------------------------------------------- */

const migrationDir = join(root, "supabase", "migrations");
for (const entry of readdirSync(migrationDir).filter((f) => f.endsWith(".sql"))) {
  const src = readFileSync(join(migrationDir, entry), "utf8");
  const rel = `supabase/migrations/${entry}`;

  for (const m of src.matchAll(/has_permission\(\s*'([a-z0-9_.]+)'\s*\)/g)) {
    if (!sqlPermissions.has(m[1])) {
      errors.push(`${rel}: references unknown permission "${m[1]}"`);
    }
  }
  for (const m of src.matchAll(/has_any_permission\(array\[([^\]]*)\]\)/g)) {
    for (const k of m[1].matchAll(/'([a-z0-9_.]+)'/g)) {
      if (!sqlPermissions.has(k[1])) {
        errors.push(`${rel}: references unknown permission "${k[1]}"`);
      }
    }
  }
  // has_permission_in_department / _in_business_unit take a key argument too.
  for (const m of src.matchAll(/has_permission_in_(?:department|business_unit)\(\s*'([a-z0-9_.]+)'/g)) {
    if (!sqlPermissions.has(m[1])) {
      errors.push(`${rel}: references unknown permission "${m[1]}"`);
    }
  }
}

/* -------------------------------------------------------------------------- */
/* 6. Report                                                                   */
/* -------------------------------------------------------------------------- */

notes.push(`${sqlPermissions.size} permissions in SQL`);
notes.push(`${tsPermissions.size} permissions in TypeScript`);
notes.push(`${sourceFiles.length} source files + ${readdirSync(migrationDir).length} migrations scanned`);

if (errors.length) {
  console.error("Permission catalogue drift detected:\n");
  for (const e of errors) console.error(`  - ${e}`);
  console.error("");
  process.exit(1);
}

console.log("Permission catalogue consistent.");
for (const n of notes) console.log(`  ${n}`);
