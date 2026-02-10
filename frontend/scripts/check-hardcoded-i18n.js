const fs = require('fs');
const path = require('path');
const { parse } = require('parse5');
const ts = require('typescript');

const REPO_ROOT = path.join(__dirname, '..');
const SRC_DIR = path.join(REPO_ROOT, 'src');
const TRANSLATION_FILE = path.join(SRC_DIR, 'assets', 'i18n', 'ja.json');
const OUTPUT_DIR = path.join(REPO_ROOT, 'i18n-extraction');
const OUTPUT_FILE = path.join(OUTPUT_DIR, 'hardcoded-report.json');

const IGNORED_DIRECTORIES = ['node_modules', 'dist', 'assets', 'i18n-extraction', '.git'];
const ATTRIBUTES_TO_CHECK = ['placeholder', 'title', 'alt', 'aria-label', 'matTooltip'];
const IGNORED_TEXT_PARENTS = new Set(['script', 'style']);
const UI_PROPERTY_PATTERNS = ['label', 'title', 'button', 'message', 'placeholder', 'tooltip', 'error', 'text'];
const MONITORED_TRANSLATION_CLASSES = [
  'btn-primary',
  'btn-secondary',
  'btn-tertiary',
  'mat-raised-button',
  'mat-flat-button',
  'mat-stroked-button'
];
const JAPANESE_REGEX = /[ぁ-んァ-ヶ一-龥々ー]/;
const ENGLISH_ALPHA_REGEX = /[A-Za-z]/;
// Angular 制御構文 (@if, @else, @for, @switch, @case, @empty, @defer, } のみ) を
// parse5 がテキストノードとして解析してしまうため、除外する正規表現
const ANGULAR_CONTROL_FLOW_REGEX = /^[\s\n}]*(@if|@else|@for|@switch|@case|@empty|@defer|@let)\b/;
const CLOSING_BRACE_ONLY_REGEX = /^[\s\n}]+$/;
const findings = [];

function ensureOutputDir() {
  if (!fs.existsSync(OUTPUT_DIR)) {
    fs.mkdirSync(OUTPUT_DIR, { recursive: true });
  }
}

function normalizePath(filePath) {
  const relative = path.relative(SRC_DIR, filePath);
  return relative.replace(/\\/g, '/').replace(/\.(html|ts)$/, '').replace(/\//g, '.').replace(/\.$/, '').toLowerCase();
}

function normalizeDescriptor(text) {
  const normalized = text
    .trim()
    .replace(/\s+/g, '_')
    .replace(/[^a-zA-Z0-9_]/g, '');

  return normalized || 'text';
}

function proposeAutoKey(filePath, contextType, text) {
  const normalizedPath = normalizePath(filePath);
  const descriptor = normalizeDescriptor(text).substring(0, 20);
  return `auto.${normalizedPath}.${contextType}_${descriptor}`;
}

function getSnippet(filePath, lineNumber, contextLines = 1) {
  try {
    const content = fs.readFileSync(filePath, 'utf-8').split('\n');
    const start = Math.max(0, lineNumber - contextLines - 1);
    const end = Math.min(content.length, lineNumber + contextLines);
    return content.slice(start, end).join('\n');
  } catch {
    return '';
  }
}

function getClassAttributeValue(node) {
  const classAttr = node.attrs?.find(attr => attr.name === 'class');
  return classAttr?.value || '';
}

function elementHasMonitoredClass(node) {
  if (!node.attrs) return false;

  const classValue = getClassAttributeValue(node);
  if (classValue) {
    const classes = classValue
      .split(/\s+/)
      .map(item => item.trim())
      .filter(Boolean);
    if (classes.some(cls => MONITORED_TRANSLATION_CLASSES.includes(cls))) {
      return true;
    }
  }

  return node.attrs.some(attr => {
    const match = attr.name.match(/^\[class\.([^\]]+)\]$/);
    if (match && MONITORED_TRANSLATION_CLASSES.includes(match[1])) {
      return true;
    }
    return false;
  });
}

function elementUsesTranslate(node) {
  if (!node.attrs) return false;

  return node.attrs.some(attr => {
    const name = attr.name.toLowerCase();
    const value = attr.value || '';
    if (name === 'translate' || name === '[translate]' || name.includes('translate')) {
      return true;
    }
    if (value.includes('| translate')) {
      return true;
    }
    return false;
  });
}

function checkMonitoredElementTranslation(node, filePath, text, line) {
  if (!elementHasMonitoredClass(node)) return;
  if (elementUsesTranslate(node)) return;
  if (!text || text.includes('{{') || text.includes('| translate')) return;
  if (hasJapanese(text)) return;

  const snippetLine = line || node.sourceCodeLocation?.startLine;
  if (!snippetLine) return;

  const suggestion = `translate パイプや属性で翻訳を追加 (例: {{ '${proposeAutoKey(filePath, 'monitored_class', text)}' | translate }})`;

  recordFinding({
    file: filePath,
    line: snippetLine,
    text,
    context: getSnippet(filePath, snippetLine),
    severity: 'medium',
    type: 'monitored_class_missing_translate',
    suggestion
  });
}

function loadTranslations() {
  if (!fs.existsSync(TRANSLATION_FILE)) {
    return { keys: new Set(), values: new Map() };
  }

  const raw = fs.readFileSync(TRANSLATION_FILE, 'utf-8');
  const parsed = JSON.parse(raw);

  const values = new Map();

  (function traverse(obj, prefix = '') {
    Object.entries(obj || {}).forEach(([key, value]) => {
      const nextKey = prefix ? `${prefix}.${key}` : key;
      if (typeof value === 'string') {
        const entries = values.get(value) || [];
        entries.push(nextKey);
        values.set(value, entries);
      } else if (typeof value === 'object' && value !== null) {
        traverse(value, nextKey);
      }
    });
  })(parsed);

  return { keys: parsed, values };
}

function hasJapanese(text) {
  return JAPANESE_REGEX.test(text);
}

function hasEnglish(text) {
  return ENGLISH_ALPHA_REGEX.test(text);
}

/**
 * Angular 制御構文のテキストノードかどうかを判定する。
 * parse5 は @if/@else/@for 等を HTML テキストとして扱うため、
 * これらを「ハードコード英語」として誤検出しないようフィルタする。
 */
function isAngularControlFlow(text) {
  return ANGULAR_CONTROL_FLOW_REGEX.test(text) || CLOSING_BRACE_ONLY_REGEX.test(text);
}

function isMasterComponent(filePath) {
  return filePath.includes(`${path.sep}components${path.sep}masters${path.sep}`);
}

function recordFinding({ file, line, text, context, severity, type, suggestion }) {
  findings.push({
    file: path.relative(REPO_ROOT, file),
    line,
    text,
    context,
    severity,
    type,
    suggestion
  });
}

function getAttributeLine(loc, name) {
  if (loc.attrs && loc.attrs[name]) {
    return loc.attrs[name].startLine;
  }
  return loc.startLine;
}

function scanTemplateContent(content, filePath, translationValues, lineOffset = 0) {
  const document = parse(content, { sourceCodeLocationInfo: true });

  function visit(node) {
    if (!node) return;

    if (node.nodeName === '#text') {
      const text = (node.value || '').trim();
      if (text && !text.includes('{{')) {
        if (hasJapanese(text)) {
          // 日本語の直接表記は既存の判定で拾える
          const parentTag =
            node.parentNode?.tagName?.toLowerCase() || node.parentNode?.nodeName?.toLowerCase();
          if (parentTag && !IGNORED_TEXT_PARENTS.has(parentTag)) {
            const loc = node.sourceCodeLocation;
            if (loc && loc.startLine) {
              const line = loc.startLine + lineOffset;
              const suggestion =
                translationValues.values.get(text)?.[0] ||
                `翻訳キーを追加 (例: ${proposeAutoKey(filePath, 'template_text', text)})`;

              recordFinding({
                file: filePath,
                line,
                text,
                context: getSnippet(filePath, line),
                severity: 'high',
                type: 'template_text',
                suggestion
              });
            }
          }
        } else if (hasEnglish(text) && isMasterComponent(filePath) && !isAngularControlFlow(text)) {
          // マスタ一覧系で英語ラベルを直接書いている箇所を検出
          // Angular 制御構文 (@if, @else, @for 等) は除外
          const loc = node.sourceCodeLocation;
          if (loc && loc.startLine) {
            const line = loc.startLine + lineOffset;
            recordFinding({
              file: filePath,
              line,
              text,
              context: getSnippet(filePath, line),
              severity: 'medium',
              type: 'template_text_english',
              suggestion: 'translate pipe か翻訳キーを使って言語を切り替える構造にしてください'
            });
          }
        }
      }

      if (text && !text.includes('{{') && !text.includes('| translate') && !isAngularControlFlow(text)) {
        const parentElement = node.parentNode;
        if (parentElement && parentElement.tagName && !hasJapanese(text)) {
          const loc = node.sourceCodeLocation;
          const line = loc?.startLine ? loc.startLine + lineOffset : undefined;
          checkMonitoredElementTranslation(parentElement, filePath, text, line);
        }
      }
    }

    if (node.attrs) {
      node.attrs.forEach(attr => {
        if (!ATTRIBUTES_TO_CHECK.includes(attr.name)) return;

        const value = attr.value;
        if (value && !value.includes('{{')) {
          const loc = node.sourceCodeLocation;
          const line = getAttributeLine(loc, attr.name) + lineOffset;
          if (hasJapanese(value)) {
            const suggestion =
              translationValues.values.get(value)?.[0] ||
              `翻訳キーを追加 (例: ${proposeAutoKey(filePath, `attr_${attr.name}`, value)})`;

            recordFinding({
              file: filePath,
              line,
              text: value,
              context: getSnippet(filePath, line),
              severity: 'high',
              type: `attribute_${attr.name}`,
              suggestion
            });
          } else if (hasEnglish(value) && isMasterComponent(filePath)) {
            recordFinding({
              file: filePath,
              line,
              text: value,
              context: getSnippet(filePath, line),
              severity: 'medium',
              type: `attribute_${attr.name}_english`,
              suggestion: 'aria-label なども translate pipe を使い、英語を直接書かないでください'
            });
          }
        }
      });
    }

    if (node.childNodes) {
      node.childNodes.forEach(child => visit(child));
    }
  }

  visit(document);
}

function scanHtmlFile(filePath, translationValues) {
  const content = fs.readFileSync(filePath, 'utf-8');
  scanTemplateContent(content, filePath, translationValues);
}

function isConsoleCall(node) {
  if (!ts.isCallExpression(node)) return false;
  const expressionText = node.expression.getText();
  return expressionText.startsWith('console.');
}

function isUIContextCall(node) {
  if (!ts.isCallExpression(node)) return false;

  const { expression } = node;
  const text = expression.getText();
  if (text.includes('snackBar') || text.includes('dialog') || text.includes('toast') || text.includes('alert') || text.includes('confirm')) {
    return true;
  }

  return false;
}

function scanTsFile(filePath, translationValues) {
  const content = fs.readFileSync(filePath, 'utf-8');
  const sourceFile = ts.createSourceFile(filePath, content, ts.ScriptTarget.Latest, true);

  function visit(node) {
    if (
      ts.isPropertyAssignment(node) &&
      ts.isIdentifier(node.name) &&
      node.name.text === 'template' &&
      ts.isNoSubstitutionTemplateLiteral(node.initializer)
    ) {
      const templateLine = sourceFile.getLineAndCharacterOfPosition(node.initializer.getStart()).line + 1;
      const lineOffset = templateLine - 1;
      scanTemplateContent(node.initializer.text, filePath, translationValues, lineOffset);
    }

    if (ts.isStringLiteral(node) && hasJapanese(node.text)) {
      const text = node.text.trim();
      const { line } = sourceFile.getLineAndCharacterOfPosition(node.getStart());

      const parent = node.parent;
      let severity = 'low';
      let type = 'ts_string';

      if (ts.isPropertyAssignment(parent) && ts.isIdentifier(parent.name)) {
        const propertyName = parent.name.text.toLowerCase();
        if (UI_PROPERTY_PATTERNS.some(pattern => propertyName.includes(pattern))) {
          severity = 'high';
          type = `ts_property_${propertyName}`;
        }
      } else if (ts.isCallExpression(parent) && !isConsoleCall(parent) && isUIContextCall(parent)) {
        severity = 'medium';
        type = 'ts_ui_call';
      }

      const suggestion =
        translationValues.values.get(text)?.[0] ||
        `翻訳キーを追加 (例: ${proposeAutoKey(filePath, 'ts_string', text)})`;

      recordFinding({
        file: filePath,
        line: line + 1,
        text,
        context: getSnippet(filePath, line + 1),
        severity,
        type,
        suggestion
      });
    }

    ts.forEachChild(node, visit);
  }

  visit(sourceFile);
}

function walkDirectory(dir, translationValues) {
  const entries = fs.readdirSync(dir);

  entries.forEach(entry => {
    const filePath = path.join(dir, entry);
    const stat = fs.statSync(filePath);

    if (stat.isDirectory()) {
      if (!IGNORED_DIRECTORIES.includes(entry)) {
        walkDirectory(filePath, translationValues);
      }
    } else if (filePath.endsWith('.html')) {
      scanHtmlFile(filePath, translationValues);
    } else if (filePath.endsWith('.ts') && !filePath.endsWith('.spec.ts')) {
      scanTsFile(filePath, translationValues);
    }
  });
}

function summarizeFindings() {
  const bySeverity = findings.reduce((acc, f) => {
    acc[f.severity] = (acc[f.severity] || 0) + 1;
    return acc;
  }, {});

  return {
    generatedAt: new Date().toISOString(),
    summary: {
      totalFindings: findings.length,
      bySeverity
    },
    findings
  };
}

function main() {
  ensureOutputDir();
  const translations = loadTranslations();
  if (!fs.existsSync(SRC_DIR)) {
    console.error('frontend/src が見つかりません。');
    process.exit(1);
  }

  walkDirectory(SRC_DIR, translations);

  fs.writeFileSync(OUTPUT_FILE, JSON.stringify(summarizeFindings(), null, 2), 'utf-8');
  console.log(`検出結果を出力しました: ${OUTPUT_FILE} (${findings.length}件)`);
}

main();
