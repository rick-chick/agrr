export type ContactFormViewState = {
  loading: boolean;
  sending: boolean;
  error: string | null;
  success: string | null;
};

export interface ContactFormView {
  get control(): ContactFormViewState;
  set control(value: ContactFormViewState);
}

