#!/usr/bin/env node
// Copies the Capsule skills from the capsule3 monorepo (libs/ai/skills) into ./skills,
// adapting portal-only tool names and limits to the Capsule MCP server, mirroring
// libs/ai/src/skills/mcp-adaptation.ts.
//
// Usage: node scripts/sync-skills.mjs [path-to-capsule3]   (default: ../capsule3)

import { cpSync, readdirSync, readFileSync, rmSync, statSync, writeFileSync } from 'node:fs';
import { dirname, join, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

const SKILLS = ['report-builder', 'supply-chain-analysis', 'capsule-brand'];

const REPLACEMENTS = [
  [
    'open it with `read_file`\n(path `/skills/report-builder/references/reports/<file>`)',
    'open it from `references/reports/<file>` in this skill\'s directory',
  ],
  [
    'Open references with `read_file`, path `/skills/supply-chain-analysis/references/<file>`.',
    'Open references from the `references/` directory next to this skill.',
  ],
  ['with `read_file`\nand follow', 'and follow'],
  ['Use `AskQuestion` to confirm the depth', 'ask the user in conversation to confirm the depth'],
  ['(4KB cap, 5 calls per turn)', '(~16 KB cap, truncated lists carry a `__truncated` marker)'],
  ['live portal data', 'live Capsule data'],
  ['query_data', 'query_graphql'],
];
const PORTAL_RESPONSE_CAP_PATTERN = /~4 KB, arrays\s+truncated to\s+~25 items, 5 calls\/turn/g;
const MCP_RESPONSE_CAP_TEXT = '~16 KB, truncated lists carry a __truncated marker';

const root = resolve(dirname(fileURLToPath(import.meta.url)), '..');
const source = join(resolve(process.argv[2] ?? join(root, '..', 'capsule3')), 'libs', 'ai', 'skills');

function adapt(text) {
  const replaced = REPLACEMENTS.reduce((acc, [from, to]) => acc.split(from).join(to), text);
  return replaced.replace(PORTAL_RESPONSE_CAP_PATTERN, MCP_RESPONSE_CAP_TEXT);
}

function adaptTree(dir) {
  for (const entry of readdirSync(dir)) {
    const path = join(dir, entry);
    if (statSync(path).isDirectory()) adaptTree(path);
    else if (path.endsWith('.md')) writeFileSync(path, adapt(readFileSync(path, 'utf8')));
  }
}

for (const skill of SKILLS) {
  const target = join(root, 'skills', skill);
  rmSync(target, { recursive: true, force: true });
  cpSync(join(source, skill), target, { recursive: true });
  adaptTree(target);
  console.log(`synced ${skill}`);
}
