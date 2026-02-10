const fs = require('fs');
const path = require('path');
const { parse } = require('parse5');
const ts = require('typescript');

const REPO_ROOT = path.join(__dirname, '..');
const SRC_DIR = path.join(__dirname, '..', 'src');
const OUTPUT_DIR = path.join(__dirname, '..', 'i18n-extraction');
const OUTPUT_FILE = path.join(OUTPUT_DIR, 'keys.json');

// Directories to ignore when walking
const IGNORED_DIRECTORIES = ['node_modules', 'dist', 'assets', 'i18n-extraction', '.git'];

// Attributes to extract from HTML
const ATTRIBUTES_TO_EXTRACT = ['placeholder', 'title', 'alt', 'aria-label', 'matTooltip'];

// Text nodes whose parent elements should be ignored
const IGNORED_TEXT_PARENTS = new Set(['script', 'style']);

// Property names that indicate UI context in TypeScript
const UI_PROPERTY_PATTERNS = ['label', 'title', 'button', 'message', 'placeholder', 'tooltip'];

// Ensure output directory exists
if (!fs.existsSync(OUTPUT_DIR)) {
  fs.mkdirSync(OUTPUT_DIR, { recursive: true });
}

const entries = [];

/**
 * Normalize a file path to create a key prefix
 */
function normalizePath(filePath) {
  const relativePath = path.relative(SRC_DIR, filePath);
  return relativePath
    .replace(/\\/g, '/')
    .replace(/\.(html|ts)$/, '')
    .replace(/\//g, '.')
    .toLowerCase();
}

/**
 * Normalize text to create a descriptor
 */
function normalizeDescriptor(text) {
  const normalized = text
    .trim()
    .replace(/\s+/g, '_')
    .replace(/[^a-zA-Z0-9_]/g, '')
    .substring(0, 30)
    .toLowerCase();
  
  // Fallback to meaningful defaults if normalization results in empty string
  if (!normalized) {
    return 'text';
  }
  
  return normalized;
}

/**
 * Get a meaningful descriptor with fallback options
 */
function getDescriptor(text, fallback = 'text') {
  const descriptor = normalizeDescriptor(text);
  return descriptor || fallback;
}

/**
 * Generate a unique key for an entry
 */
function generateKey(normalizedPath, type, descriptor, index) {
  // index is the count of existing entries with the same pattern
  // First entry gets no suffix (index 0), subsequent entries get _1, _2, etc.
  const suffix = index > 0 ? `_${index}` : '';
  return `auto.${normalizedPath}.${type}_${descriptor}${suffix}`;
}

/**
 * Get a code snippet around a line number
 */
function getSnippet(filePath, lineNumber, contextLines = 2) {
  try {
    const content = fs.readFileSync(filePath, 'utf-8');
    const lines = content.split('\n');
    const start = Math.max(0, lineNumber - contextLines - 1);
    const end = Math.min(lines.length, lineNumber + contextLines);
    return lines.slice(start, end).join('\n');
  } catch (e) {
    return '';
  }
}

/**
 * Check if text contains Angular interpolation
 */
function hasInterpolation(text) {
  return /\{\{.*\}\}/.test(text);
}

/**
 * Check if attribute value contains dynamic binding
 */
function hasDynamicBinding(value) {
  return typeof value === 'string' && value.includes('{{');
}

/**
 * Extract text nodes from HTML template
 */
function extractTextNodes(node, filePath) {
  if (!node) return;

  if (node.nodeName === '#text') {
    const text = node.value?.trim();
    if (text && text.length > 0 && !hasInterpolation(text)) {
      // Skip text nodes whose parent is script or style
      const parentTagName = node.parentNode?.tagName?.toLowerCase() || node.parentNode?.nodeName?.toLowerCase();
      if (parentTagName && IGNORED_TEXT_PARENTS.has(parentTagName)) {
        return;
      }
      
      const loc = node.sourceCodeLocation;
      if (loc && loc.startLine) {
        const normalizedPath = normalizePath(filePath);
        const descriptor = getDescriptor(text, 'text');
        
        // Find existing entries with same key pattern to determine index
        const existingCount = entries.filter(e => 
          e.key.startsWith(`auto.${normalizedPath}.template_text_${descriptor}`)
        ).length;
        
        entries.push({
          key: generateKey(normalizedPath, 'template_text', descriptor, existingCount),
          type: 'template-text',
          file: path.relative(REPO_ROOT, filePath),
          line: loc.startLine,
          text: text,
          snippet: getSnippet(filePath, loc.startLine)
        });
      }
    }
  }

  if (node.childNodes) {
    node.childNodes.forEach(child => {
      extractTextNodes(child, filePath);
    });
  }
}

/**
 * Extract attributes from HTML template
 */
function extractAttributes(node, filePath) {
  if (!node || !node.attrs) return;

  node.attrs.forEach(attr => {
    if (ATTRIBUTES_TO_EXTRACT.includes(attr.name)) {
      const value = attr.value;
      if (value && !hasDynamicBinding(value)) {
        const loc = node.sourceCodeLocation;
        if (loc) {
          // Use attrs entry for line number if present, otherwise fall back to element's start line
          let lineNumber = null;
          if (loc.attrs && loc.attrs[attr.name]) {
            lineNumber = loc.attrs[attr.name].startLine;
          } else if (loc.startLine) {
            lineNumber = loc.startLine;
          }
          
          if (lineNumber) {
            const normalizedPath = normalizePath(filePath);
            const descriptor = getDescriptor(value, 'value');
            
            const existingCount = entries.filter(e => 
              e.key.startsWith(`auto.${normalizedPath}.template_attr_${attr.name}_${descriptor}`)
            ).length;
            
            entries.push({
              key: generateKey(normalizedPath, `template_attr_${attr.name}`, descriptor, existingCount),
              type: `template-attr-${attr.name}`,
              file: path.relative(REPO_ROOT, filePath),
              line: lineNumber,
              text: value,
              snippet: getSnippet(filePath, lineNumber)
            });
          }
        }
      }
    }
  });

  if (node.childNodes) {
    node.childNodes.forEach(child => {
      extractAttributes(child, filePath);
    });
  }
}

/**
 * Process HTML file
 */
function processHtmlFile(filePath) {
  try {
    const content = fs.readFileSync(filePath, 'utf-8');
    const document = parse(content, {
      sourceCodeLocationInfo: true
    });
    
    extractTextNodes(document, filePath);
    extractAttributes(document, filePath);
  } catch (e) {
    console.error(`Error processing HTML file ${filePath}:`, e.message);
  }
}

/**
 * Check if a property name matches UI patterns
 */
function isUIProperty(name) {
  return UI_PROPERTY_PATTERNS.some(pattern => 
    name.toLowerCase().includes(pattern.toLowerCase())
  );
}

/**
 * Check if a call expression is a UI context call
 */
function isUIContextCall(node) {
  if (!ts.isCallExpression(node)) return false;
  
  const expression = node.expression;
  if (ts.isPropertyAccessExpression(expression)) {
    const name = expression.name?.text;
    const target = expression.expression;
    
    // Check for snackBar.open, dialog.open
    if (name === 'open') {
      const targetText = target.getText();
      if (targetText.includes('snackBar') || targetText.includes('dialog')) {
        return true;
      }
    }
  }
  
  // Check for confirm, alert
  if (ts.isIdentifier(expression)) {
    const name = expression.text;
    if (name === 'confirm' || name === 'alert') {
      return true;
    }
  }
  
  return false;
}

/**
 * Extract string literals from TypeScript AST
 */
function extractStringLiterals(node, sourceFile, filePath) {
  if (!node) return;

  // Extract string literals in UI context calls
  if (isUIContextCall(node)) {
    node.arguments.forEach(arg => {
      if (ts.isStringLiteral(arg)) {
        const text = arg.text;
        if (text && text.trim().length > 0) {
          const pos = sourceFile.getLineAndCharacterOfPosition(arg.getStart());
          const normalizedPath = normalizePath(filePath);
          const descriptor = normalizeDescriptor(text);
          
          const existingCount = entries.filter(e => 
            e.key.startsWith(`auto.${normalizedPath}.ts_call_${descriptor}`)
          ).length;
          
          entries.push({
            key: generateKey(normalizedPath, 'ts_call', descriptor, existingCount),
            type: 'ts_call',
            file: path.relative(REPO_ROOT, filePath),
            line: pos.line + 1,
            text: text,
            snippet: getSnippet(filePath, pos.line + 1)
          });
        }
      }
    });
  }

  // Extract property assignments with UI-related names
  if (ts.isPropertyAssignment(node)) {
    const name = node.name;
    if (name && ts.isIdentifier(name) && isUIProperty(name.text)) {
      const initializer = node.initializer;
      if (initializer && (ts.isStringLiteral(initializer) || ts.isNoSubstitutionTemplateLiteral(initializer))) {
        const text = initializer.text;
        if (text && text.trim().length > 0) {
          const pos = sourceFile.getLineAndCharacterOfPosition(initializer.getStart());
          const normalizedPath = normalizePath(filePath);
          const descriptor = getDescriptor(text, 'property');
          const propName = name.text.toLowerCase();
          
          const existingCount = entries.filter(e => 
            e.key.startsWith(`auto.${normalizedPath}.ts_prop_${propName}_${descriptor}`)
          ).length;
          
          entries.push({
            key: generateKey(normalizedPath, `ts_prop_${propName}`, descriptor, existingCount),
            type: `ts_prop_${propName}`,
            file: path.relative(REPO_ROOT, filePath),
            line: pos.line + 1,
            text: text,
            snippet: getSnippet(filePath, pos.line + 1)
          });
        }
      }
    }
  }

  // Recursively visit child nodes
  ts.forEachChild(node, child => {
    extractStringLiterals(child, sourceFile, filePath);
  });
}

/**
 * Process TypeScript file
 */
function processTsFile(filePath) {
  try {
    const content = fs.readFileSync(filePath, 'utf-8');
    const sourceFile = ts.createSourceFile(
      filePath,
      content,
      ts.ScriptTarget.Latest,
      true
    );
    
    extractStringLiterals(sourceFile, sourceFile, filePath);
  } catch (e) {
    console.error(`Error processing TypeScript file ${filePath}:`, e.message);
  }
}

/**
 * Recursively walk directory and process files
 */
function walkDirectory(dir) {
  const files = fs.readdirSync(dir);
  
  files.forEach(file => {
    const filePath = path.join(dir, file);
    const stat = fs.statSync(filePath);
    
    if (stat.isDirectory()) {
      // Skip ignored directories
      if (!IGNORED_DIRECTORIES.includes(file)) {
        walkDirectory(filePath);
      }
    } else if (file.endsWith('.html')) {
      processHtmlFile(filePath);
    } else if (file.endsWith('.ts') && !file.endsWith('.spec.ts')) {
      processTsFile(filePath);
    }
  });
}

/**
 * Main execution
 */
function main() {
  console.log('Extracting i18n keys from frontend/src...');
  
  if (!fs.existsSync(SRC_DIR)) {
    console.error(`Source directory not found: ${SRC_DIR}`);
    process.exit(1);
  }
  
  walkDirectory(SRC_DIR);
  
  // Sort entries by key
  entries.sort((a, b) => a.key.localeCompare(b.key));
  
  // Count entries by type
  const typeCounts = {};
  entries.forEach(entry => {
    typeCounts[entry.type] = (typeCounts[entry.type] || 0) + 1;
  });
  
  // Write output
  const output = {
    generatedAt: new Date().toISOString(),
    entries: entries
  };
  
  fs.writeFileSync(OUTPUT_FILE, JSON.stringify(output, null, 2), 'utf-8');
  
  // Print summary
  console.log('\nExtraction complete!');
  console.log(`Total entries: ${entries.length}`);
  console.log('\nEntries by type:');
  Object.entries(typeCounts)
    .sort((a, b) => b[1] - a[1])
    .forEach(([type, count]) => {
      console.log(`  ${type}: ${count}`);
    });
  console.log(`\nOutput written to: ${OUTPUT_FILE}`);
}

main();
