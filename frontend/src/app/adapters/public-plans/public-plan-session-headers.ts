export const PUBLIC_PLAN_SESSION_HEADER = 'X-Public-Plan-Session';

export function publicPlanSessionHeaders(sessionToken: string): Record<string, string> {
  return { [PUBLIC_PLAN_SESSION_HEADER]: sessionToken };
}
