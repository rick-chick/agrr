export interface ContactMessagePayload {
  name?: string | null;
  email: string;
  subject?: string | null;
  message: string;
  source?: string | null;
}

export type ContactMessageStatus = 'sent' | 'failed' | 'queued';

export interface ContactMessageRecord {
  id: number;
  name?: string | null;
  email: string;
  subject?: string | null;
  message: string;
  source?: string | null;
  status: ContactMessageStatus;
  created_at: string;
  sent_at?: string | null;
}

// Basic validation helpers used by frontend unit tests / presenters.
export const EMAIL_REGEX =
  /^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$/;

export function validateEmail(email: string | undefined | null): boolean {
  if (!email) return false;
  return EMAIL_REGEX.test(email);
}

export interface ContactMessageValidationSuccess {
  valid: true;
}

export interface ContactMessageValidationFailure {
  valid: false;
  message: string;
}

export type ContactMessageValidationResult =
  | ContactMessageValidationSuccess
  | ContactMessageValidationFailure;

export function isValidationFailure(
  result: ContactMessageValidationResult
): result is ContactMessageValidationFailure {
  return result.valid === false;
}

export function validatePayload(payload: ContactMessagePayload): ContactMessageValidationResult {
  if (!payload.message || payload.message.trim().length === 0) {
    return { valid: false, message: 'contact_form.validation.message_required' };
  }
  if (payload.message.length > 5000) {
    return { valid: false, message: 'contact_form.validation.message_too_long' };
  }
  if (payload.name && payload.name.length > 255) {
    return { valid: false, message: 'contact_form.validation.name_too_long' };
  }
  if (payload.subject && payload.subject.length > 255) {
    return { valid: false, message: 'contact_form.validation.subject_too_long' };
  }
  const email = payload.email?.trim();
  if (!email || email.length === 0) {
    return { valid: false, message: 'contact_form.validation.email_required' };
  }
  if (!validateEmail(email)) {
    return { valid: false, message: 'contact_form.validation.email_invalid' };
  }
  return { valid: true };
}

