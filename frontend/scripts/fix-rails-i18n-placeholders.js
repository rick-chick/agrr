#!/usr/bin/env node
/**
 * Convert Rails I18n placeholders (%{name}) to ngx-translate ({{name}}).
 * Also repairs half-converted {{name} -> {{name}}.
 */
const fs = require('fs');
const path = require('path');

const I18N_DIR = path.join(__dirname, '..', 'src', 'assets', 'i18n');
const FILES = ['ja.json', 'en.json', 'in.json'];

const RAILS_PLACEHOLDER = /%\{([a-zA-Z_][a-zA-Z0-9_]*)\}/g;
const BROKEN_NGX = /\{\{([a-zA-Z_][a-zA-Z0-9_]*)\}(?!\})/g;

for (const file of FILES) {
  const filePath = path.join(I18N_DIR, file);
  let content = fs.readFileSync(filePath, 'utf8');
  const beforeRails = (content.match(RAILS_PLACEHOLDER) || []).length;
  content = content.replace(RAILS_PLACEHOLDER, '{{$1}}');
  const beforeBroken = (content.match(BROKEN_NGX) || []).length;
  content = content.replace(BROKEN_NGX, '{{$1}}');
  fs.writeFileSync(filePath, content);
  JSON.parse(content);
  console.log(
    `${file}: rails=%{…} fixed ${beforeRails}, broken {{…} fixed ${beforeBroken}`
  );
}
