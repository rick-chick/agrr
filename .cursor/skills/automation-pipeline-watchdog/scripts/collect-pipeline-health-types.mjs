/**
 * @typedef {{
 *   number: number;
 *   title: string;
 *   state: string;
 *   score: number;
 * }} IssueCandidate
 */

/**
 * @typedef {{
 *   id: string;
 *   category: 'issue' | 'pr' | 'workflow' | 'bootstrap';
 *   priority: 'P0' | 'P1' | 'P2';
 *   subjectType: 'issue' | 'pr' | 'workflow_run' | 'smoke';
 *   subjectNumber: number | null;
 *   title: string;
 *   summary: string;
 *   evidence: Record<string, unknown>;
 *   suggestedLabels: string[];
 *   agentReady: boolean;
 *   existingIssueCandidates?: IssueCandidate[];
 * }} PipelineFinding
 */

export {};
