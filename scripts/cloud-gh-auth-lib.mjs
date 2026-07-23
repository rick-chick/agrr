export const PROFILE_SNIPPET_MARKER = '# cursor-cloud-gh-auth';

/**
 * Resolve shell env so `gh` uses the user PAT instead of Cursor integration token.
 * Only AGRR_GH_PAT is considered; integration tokens are never promoted.
 *
 * @param {{ agrrGhPat?: string | null }} input
 */
export function buildGhAuthEnv({ agrrGhPat }) {
  if (!agrrGhPat) {
    return { ghToken: null, unsetGithubToken: false };
  }
  return { ghToken: agrrGhPat, unsetGithubToken: true };
}

/**
 * Bash snippet sourced from login shells to re-apply PAT auth after Cursor injects GITHUB_TOKEN.
 */
export function buildProfileSnippet() {
  return `${PROFILE_SNIPPET_MARKER}: prefer AGRR_GH_PAT over Cursor integration token
if [[ -n "\${AGRR_GH_PAT:-}" ]]; then
  export GH_TOKEN="\$AGRR_GH_PAT"
  unset GITHUB_TOKEN 2>/dev/null || true
fi
`;
}
