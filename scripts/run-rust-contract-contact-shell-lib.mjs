import { existsSync, readFileSync } from 'node:fs';
import { join } from 'node:path';

export const RECAPTCHA_CONTRACT_MOCK_SCRIPT = 'scripts/recaptcha-contract-mock.py';

const DOCKER_BASH_C_MARKER = "test bash -c '";
const HOST_SINGLE_QUOTE_ESCAPE = '\x27\x22\x27\x22\x27';

/**
 * Extract the inner bash script passed to `docker compose ... test bash -c '...'`.
 * Honors the host-shell `'"'"'` single-quote escape inside the outer single quotes.
 */
export function extractDockerBashC(scriptText) {
  const start = scriptText.indexOf(DOCKER_BASH_C_MARKER);
  if (start < 0) {
    return { ok: false, errors: ['missing docker test bash -c block'] };
  }

  let i = start + DOCKER_BASH_C_MARKER.length;
  let inner = '';
  while (i < scriptText.length) {
    const ch = scriptText[i];
    if (ch === "'") {
      if (scriptText.startsWith(HOST_SINGLE_QUOTE_ESCAPE, i)) {
        inner += "'";
        i += 5;
        continue;
      }
      if (/^'\s*$/.test(scriptText.slice(i, scriptText.indexOf('\n', i)))) {
        break;
      }
      return {
        ok: false,
        errors: [
          'unescaped single quote inside docker bash -c block (host shell will truncate the inner script)',
        ],
      };
    }
    inner += ch;
    i += 1;
  }

  return { ok: true, inner };
}

export function extractContactPayloadCurl(innerScript) {
  const curlLine = innerScript
    .split('\n')
    .find((line) => line.includes('--data-raw') && line.includes('unconfigured-recaptcha@example.com'));
  if (!curlLine) {
    return { ok: false, errors: ['missing contact shell contract curl --data-raw line'] };
  }

  const match = curlLine.match(/--data-raw\s+'(\{.*\})'/);
  if (!match) {
    return { ok: false, errors: ['could not parse contact shell contract JSON payload from curl line'] };
  }

  return { ok: true, payload: match[1] };
}

export function verifyContactShellContractQuoting(repoRoot) {
  const scriptPath = join(repoRoot, 'scripts/run-rust-contract-tests.sh');
  const scriptText = readFileSync(scriptPath, 'utf8');
  const errors = [];

  const docker = extractDockerBashC(scriptText);
  if (!docker.ok) {
    return { ok: false, errors: docker.errors };
  }

  const curlPayload = extractContactPayloadCurl(docker.inner);
  if (!curlPayload.ok) {
    return { ok: false, errors: curlPayload.errors };
  }

  try {
    const parsed = JSON.parse(curlPayload.payload);
    if (parsed.email !== 'unconfigured-recaptcha@example.com') {
      errors.push('contact payload email mismatch');
    }
    if (!parsed.message || !parsed.recaptcha_token) {
      errors.push('contact payload missing message or recaptcha_token');
    }
  } catch (error) {
    errors.push(`contact payload is not valid JSON: ${error.message}`);
  }

  return { ok: errors.length === 0, errors };
}

export function verifyRecaptchaContractMockSetup(repoRoot) {
  const errors = [];
  const dockerfilePath = join(repoRoot, 'Dockerfile.test');
  const contractScriptPath = join(repoRoot, 'scripts/run-rust-contract-tests.sh');
  const mockScriptPath = join(repoRoot, RECAPTCHA_CONTRACT_MOCK_SCRIPT);

  if (!existsSync(mockScriptPath)) {
    errors.push(`missing ${RECAPTCHA_CONTRACT_MOCK_SCRIPT}`);
  }

  const dockerfile = readFileSync(dockerfilePath, 'utf8');
  if (!/python3(?:-minimal)?/.test(dockerfile)) {
    errors.push('Dockerfile.test must install python3 for reCAPTCHA contract mock');
  }

  const contractScript = readFileSync(contractScriptPath, 'utf8');
  if (!contractScript.includes(RECAPTCHA_CONTRACT_MOCK_SCRIPT)) {
    errors.push('run-rust-contract-tests.sh must start recaptcha-contract-mock.py');
  }
  if (!contractScript.includes('127.0.0.1:9191/siteverify')) {
    errors.push('run-rust-contract-tests.sh must wait for reCAPTCHA mock readiness');
  }

  return { ok: errors.length === 0, errors };
}
