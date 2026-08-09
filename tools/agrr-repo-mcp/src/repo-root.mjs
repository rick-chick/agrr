import { fileURLToPath } from 'node:url';
import { dirname, join } from 'node:path';

const PACKAGE_SRC_DIR = dirname(fileURLToPath(import.meta.url));

/** Workspace root (tools/agrr-repo-mcp/src → repo root). */
export const DEFAULT_REPO_ROOT = join(PACKAGE_SRC_DIR, '../../..');
