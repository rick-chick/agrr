import { readFileSync, existsSync } from 'node:fs';
import { join } from 'node:path';

const REQUIRED_HEADER_NAMES = [
  'Strict-Transport-Security',
  'X-Content-Type-Options',
  'Referrer-Policy',
  'X-Frame-Options',
  'Content-Security-Policy-Report-Only',
];
const RUST_HEADER_MARKERS = [
  'STRICT_TRANSPORT_SECURITY',
  'X_CONTENT_TYPE_OPTIONS',
  'REFERRER_POLICY',
  'X_FRAME_OPTIONS',
  'CONTENT_SECURITY_POLICY_REPORT_ONLY',
];

const REQUIRED_BACKENDS = [
  'agrr-frontend-backend',
  'agrr-research-backend',
  'rust-backend',
];

/**
 * @param {string} repoRoot
 * @returns {{ ok: boolean, errors: string[] }}
 */
export function verifySecurityResponseHeadersContract(repoRoot) {
  const errors = [];

  const headersYamlPath = join(repoRoot, 'scripts/agrr-security-response-headers.yaml');
  if (!existsSync(headersYamlPath)) {
    errors.push(`missing ${headersYamlPath}`);
    return { ok: false, errors };
  }

  const headersYaml = readFileSync(headersYamlPath, 'utf8');
  for (const name of REQUIRED_HEADER_NAMES) {
    if (!headersYaml.includes(`${name}:`)) {
      errors.push(`scripts/agrr-security-response-headers.yaml missing header ${name}`);
    }
  }

  const backendsYamlPath = join(repoRoot, 'scripts/agrr-lb-backend-security-headers.yaml');
  if (!existsSync(backendsYamlPath)) {
    errors.push(`missing ${backendsYamlPath}`);
  } else {
    const backendsYaml = readFileSync(backendsYamlPath, 'utf8');
    for (const backend of REQUIRED_BACKENDS) {
      if (!backendsYaml.includes(backend)) {
        errors.push(`scripts/agrr-lb-backend-security-headers.yaml missing backend ${backend}`);
      }
    }
  }

  const applyScriptPath = join(repoRoot, 'scripts/apply-lb-security-response-headers.sh');
  if (!existsSync(applyScriptPath)) {
    errors.push(`missing ${applyScriptPath}`);
  } else {
    const applyScript = readFileSync(applyScriptPath, 'utf8');
    if (!applyScript.includes('--custom-response-header')) {
      errors.push('apply-lb-security-response-headers.sh must apply --custom-response-header flags');
    }
    if (!applyScript.includes('agrr-lb-backend-security-headers.yaml')) {
      errors.push('apply-lb-security-response-headers.sh must read agrr-lb-backend-security-headers.yaml');
    }
  }

  const rustModulePath = join(repoRoot, 'crates/agrr-server/src/security_headers.rs');
  if (!existsSync(rustModulePath)) {
    errors.push('missing crates/agrr-server/src/security_headers.rs');
  } else {
    const rustModule = readFileSync(rustModulePath, 'utf8');
    for (const marker of RUST_HEADER_MARKERS) {
      if (!rustModule.includes(marker)) {
        errors.push(`security_headers.rs missing marker ${marker}`);
      }
    }
  }

  const libRsPath = join(repoRoot, 'crates/agrr-server/src/lib.rs');
  const libRs = readFileSync(libRsPath, 'utf8');
  if (!libRs.includes('mod security_headers') || !libRs.includes('security_headers::')) {
    errors.push('lib.rs must wire security_headers middleware');
  }

  const cargoTomlPath = join(repoRoot, 'crates/agrr-server/Cargo.toml');
  const cargoToml = readFileSync(cargoTomlPath, 'utf8');
  if (!cargoToml.includes('"set-header"')) {
    errors.push('agrr-server Cargo.toml must enable tower-http set-header feature');
  }

  return { ok: errors.length === 0, errors };
}
