export type ApiKeyViewState = {
  loading: boolean;
  error: string | null;
  apiKey: string;
  copyButtonLabel: string;
  generating: boolean;
};

export interface ApiKeyView {
  get control(): ApiKeyViewState;
  set control(value: ApiKeyViewState);
}
