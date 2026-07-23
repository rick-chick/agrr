/**
 * Cloud Agent gh token resolution.
 * Cursor injects GITHUB_TOKEN (integration ghs_*) during agent sessions, which
 * overrides gh auth login from AGRR_GH_PAT. Prefer the user PAT when present.
 */

/**
 * @param {{ agrrGhPat?: string | null; ghToken?: string | null; githubToken?: string | null }} input
 * @returns {string}
 */
export function resolveGhTokenForCloudAgent(input) {
  const { agrrGhPat, ghToken, githubToken } = input;
  if (agrrGhPat) {
    return agrrGhPat;
  }
  if (ghToken) {
    return ghToken;
  }
  if (githubToken) {
    return githubToken;
  }
  return '';
}

/**
 * Env vars for a gh subprocess so integration tokens do not win over AGRR_GH_PAT.
 *
 * @param {{ agrrGhPat?: string | null; ghToken?: string | null; githubToken?: string | null }} input
 * @returns {Record<string, string | undefined>}
 */
export function buildGhExecEnv(input) {
  const token = resolveGhTokenForCloudAgent(input);
  const env = {
    GITHUB_TOKEN: undefined,
    GH_TOKEN: token || undefined,
  };
  return env;
}
