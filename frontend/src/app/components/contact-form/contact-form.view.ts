export interface ContactFormViewState {
  loading: boolean;
  sending: boolean;
  error: string | null;
  success: string | null;
}

export interface ContactFormView {
  control: ContactFormViewState;
}

