#!/usr/bin/env node
const { spawnSync } = require('node:child_process');
const path = require('node:path');

const args = process.argv.slice(2);
if (args[0] === 'init') args.shift();

const script = path.join(__dirname, '..', 'install.sh');
const result = spawnSync('bash', [script, ...args], { stdio: 'inherit' });
process.exit(result.status ?? 1);
