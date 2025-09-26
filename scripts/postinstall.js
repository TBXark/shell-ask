#!/usr/bin/env node

const { execSync } = require('child_process');
const path = require('path');
const fs = require('fs');

console.log('Setting up shell-ask...');

// Make ask.sh executable
const askPath = path.join(__dirname, '..', 'ask.sh');
if (fs.existsSync(askPath)) {
    execSync(`chmod +x "${askPath}"`);
    console.log('shell-ask has been installed successfully!');
    console.log('You can now use \'ask\' command in your terminal.');
    console.log('');
    console.log('To get started, set up your API key:');
    console.log('  ask set-config api_key YOUR_API_KEY');
    console.log('');
    console.log('For help, run:');
    console.log('  ask --help');
} else {
    console.error('Error: ask.sh not found');
    process.exit(1);
}