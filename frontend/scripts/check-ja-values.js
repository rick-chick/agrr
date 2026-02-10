const fs = require('fs');
const path = require('path');

const REPO_ROOT = path.join(__dirname, '..');
const SRC_DIR = path.join(REPO_ROOT, 'src');
const TRANSLATION_FILE = path.join(SRC_DIR, 'assets', 'i18n', 'ja.json');
const OUTPUT_DIR = path.join(REPO_ROOT, 'i18n-extraction');
const OUTPUT_FILE = path.join(OUTPUT_DIR, 'ja-value-report.json');
const JAPANESE_REGEX = /[ぁ-んァ-ヶ一-龥々ー]/;

function ensureOutputDir() {
  if (!fs.existsSync(OUTPUT_DIR)) {
    fs.mkdirSync(OUTPUT_DIR, { recursive: true });
  }
}

function hasJapanese(text) {
  return JAPANESE_REGEX.test(text);
}

function loadTranslations() {
  if (!fs.existsSync(TRANSLATION_FILE)) {
    console.error('ja.json translation file が見つかりません。');
    process.exit(1);
  }

  const raw = fs.readFileSync(TRANSLATION_FILE, 'utf-8');
  return JSON.parse(raw);
}

const findings = [];

function traverseTranslations(node, keyPath = []) {
  if (typeof node === 'string') {
    const text = node.trim();
    if (text && !hasJapanese(text)) {
      findings.push({
        key: keyPath.join('.'),
        value: text,
        message: 'ja.json の訳文に日本語が含まれていません。実際の日本語表現を記述してください。'
      });
    }
    return;
  }

  if (typeof node === 'object' && node !== null) {
    Object.entries(node).forEach(([key, value]) => {
      traverseTranslations(value, [...keyPath, key]);
    });
  }
}

function summarizeFindings() {
  return {
    generatedAt: new Date().toISOString(),
    summary: {
      totalFindings: findings.length
    },
    findings
  };
}

function main() {
  ensureOutputDir();
  const translations = loadTranslations();
  traverseTranslations(translations);

  fs.writeFileSync(OUTPUT_FILE, JSON.stringify(summarizeFindings(), null, 2), 'utf-8');
  console.log(`ja.json の英語訳を検出しました: ${OUTPUT_FILE} (${findings.length}件)`);
}

main();
