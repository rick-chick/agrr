export type ContactFormMessageVariant = 'success' | 'error' | 'validation';
export type ContactFormMessageLiveRegion = 'polite' | 'assertive';

export interface ContactFormMessage {
  text: string;
  variant: ContactFormMessageVariant;
  ariaLive: ContactFormMessageLiveRegion;
}

export interface ContactFormViewState {
  loading: boolean;
  sending: boolean;
  message: ContactFormMessage | null;
}

export interface ContactFormView {
  control: ContactFormViewState;
}

