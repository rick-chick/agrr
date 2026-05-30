#!/usr/bin/env node
/**
 * Merges visual-review i18n patches into ja/en/in.json.
 * Run: node scripts/apply-visual-review-i18n.mjs
 */
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const FRONTEND = path.join(__dirname, '..');
const I18N_DIR = path.join(FRONTEND, 'src/assets/i18n');
const PATCHES_PATH = path.join(FRONTEND, 'i18n-extraction/visual-review-patches.json');

function load(lang) {
  return JSON.parse(fs.readFileSync(path.join(I18N_DIR, `${lang}.json`), 'utf8'));
}

function save(lang, data) {
  fs.writeFileSync(path.join(I18N_DIR, `${lang}.json`), `${JSON.stringify(data, null, 2)}\n`);
}

function deepMerge(target, source) {
  for (const key of Object.keys(source)) {
    const val = source[key];
    if (val && typeof val === 'object' && !Array.isArray(val)) {
      if (!target[key] || typeof target[key] !== 'object' || Array.isArray(target[key])) {
        target[key] = {};
      }
      deepMerge(target[key], val);
    } else {
      target[key] = val;
    }
  }
}

function setPath(obj, dotPath, value) {
  const parts = dotPath.split('.');
  let cur = obj;
  for (let i = 0; i < parts.length - 1; i++) {
    if (!cur[parts[i]]) cur[parts[i]] = {};
    cur = cur[parts[i]];
  }
  cur[parts[parts.length - 1]] = value;
}

/** Clone ja.crops → en with English overrides for master CRUD UI */
function applyEnCropsFromJa(en, ja) {
  en.crops = structuredClone(ja.crops);
  const overrides = {
    'index.title': 'Crops',
    'index.description': 'Manage crop master data for your cultivation plans.',
    'index.new_crop': 'Add New Crop',
    'index.reference_crops': 'Reference Crops (Shared Data)',
    'index.my_crops': 'My Crops',
    'index.count': '{{count}} items',
    'index.actions.show': 'Details',
    'index.actions.edit': 'Edit',
    'index.actions.delete': 'Delete',
    'index.actions.delete_confirm': 'Are you sure you want to delete this crop?',
    'index.empty.title': 'No crops registered yet',
    'index.empty.description': 'Add your first crop to get started.',
    'index.empty.button': 'Add Crop',
    'index.debug.label': 'Debug:',
    'new.title': 'Add New Crop',
    'edit.title': 'Edit {{name}}',
    'edit.form.submit': 'Update Crop',
    'edit.form.cancel': 'Cancel',
    'edit.errors.title': '{{count}} error(s):',
    'show.back_to_list': 'Back to Crops',
    'show.edit': 'Edit',
    'show.delete': 'Delete',
    'show.confirm_delete': 'Delete this crop?',
    'undo.toast': '{{name}} was deleted. You can undo this action.',
    'form.submit_create': 'Create Crop',
    'form.submit_update': 'Update Crop',
    'form.cancel': 'Cancel',
    'flash.created': 'Crop was created successfully.',
    'flash.updated': 'Crop was updated successfully.',
    'flash.destroyed': 'Crop was deleted.',
    'flash.not_found': 'Crop not found.',
    'flash.no_permission': 'Permission denied.'
  };
  for (const [p, v] of Object.entries(overrides)) {
    setPath(en.crops, p, v);
  }
}

/** Clone ja.crops → in with Hindi overrides (list/detail chrome) */
function applyInCropsFromJa(inLoc, ja) {
  inLoc.crops = structuredClone(ja.crops);
  const overrides = {
    'index.title': 'फसल सूची',
    'index.description': 'अपनी खेती योजनाओं के लिए फसल मास्टर डेटा प्रबंधित करें।',
    'index.new_crop': 'नई फसल जोड़ें',
    'index.reference_crops': 'संदर्भ फसल (साझा डेटा)',
    'index.my_crops': 'मेरी फसलें',
    'index.count': '{{count}} आइटम',
    'index.actions.show': 'विवरण',
    'index.actions.edit': 'संपादित करें',
    'index.actions.delete': 'हटाएं',
    'index.actions.delete_confirm': 'क्या आप इस फसल को हटाना चाहते हैं?',
    'index.empty.title': 'अभी तक कोई फसल पंजीकृत नहीं',
    'index.empty.description': 'शुरू करने के लिए अपनी पहली फसल जोड़ें।',
    'index.empty.button': 'फसल जोड़ें',
    'new.title': 'नई फसल जोड़ें',
    'edit.title': '{{name}} संपादित करें',
    'show.back_to_list': 'फसल सूची पर वापस',
    'undo.toast': '{{name}} हटाया गया। आप इस क्रिया को पूर्ववत कर सकते हैं।'
  };
  for (const [p, v] of Object.entries(overrides)) {
    setPath(inLoc.crops, p, v);
  }
}

const patches = JSON.parse(fs.readFileSync(PATCHES_PATH, 'utf8'));
const ja = load('ja');

for (const lang of ['ja', 'en', 'in']) {
  const data = load(lang);
  if (patches[lang]) deepMerge(data, patches[lang]);
  if (lang === 'en') applyEnCropsFromJa(data, ja);
  if (lang === 'in') applyInCropsFromJa(data, ja);
  save(lang, data);
}

console.log('Applied visual-review i18n patches to ja, en, in');
