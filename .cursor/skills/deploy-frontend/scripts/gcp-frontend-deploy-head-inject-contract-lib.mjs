/**
 * Contract checks for optional runtime globals injected into index.html by gcp-frontend-deploy.sh.
 */

/**
 * @param {string} deployScript
 * @returns {{ ok: boolean; errors: string[] }}
 */
export function verifyTurnstileSiteKeyHeadInjectContract(deployScript) {
  const errors = [];

  if (!deployScript.includes('TURNSTILE_SITE_KEY')) {
    errors.push('deploy script must read TURNSTILE_SITE_KEY from env');
  }
  if (!deployScript.includes('window.TURNSTILE_SITE_KEY')) {
    errors.push('deploy script must inject window.TURNSTILE_SITE_KEY when set');
  }

  return { ok: errors.length === 0, errors };
}
