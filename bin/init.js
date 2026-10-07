#!/usr/bin/env node
const { spawnSync } = require('node:child_process');
const path = require('node:path');

const args = process.argv.slice(2);
if (args[0] === 'init') args.shift();

const script = path.join(__dirname, '..', 'install.sh');
// Absolute interpreter path: resolving bash through $PATH would let a writable
// PATH entry hijack the installer (SonarQube javascript:S4036).
const result = spawnSync('/bin/bash', [script, ...args], { stdio: 'inherit' });
process.exit(result.status ?? 1);
