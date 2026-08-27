/** Static copy for bootstrap failure before i18n / Angular are available. */
const BOOTSTRAP_FAILURE_COPY = {
  title: 'アプリの起動に失敗しました',
  message:
    '一時的な問題が発生した可能性があります。ページを再読み込みしてお試しください。',
  reload: '再読み込み'
} as const;

export function renderBootstrapFailureFallback(host: HTMLElement): void {
  host.replaceChildren();

  const container = document.createElement('div');
  container.className = 'page-content-container app-error-fallback';

  const header = document.createElement('div');
  header.className = 'page-header';

  const title = document.createElement('h1');
  title.className = 'page-title';
  title.textContent = BOOTSTRAP_FAILURE_COPY.title;
  header.append(title);

  const content = document.createElement('div');
  content.className = 'page-content';

  const message = document.createElement('p');
  message.className = 'page-section-content';
  message.textContent = BOOTSTRAP_FAILURE_COPY.message;

  const actions = document.createElement('p');
  const reloadButton = document.createElement('button');
  reloadButton.type = 'button';
  reloadButton.className = 'btn btn-primary';
  reloadButton.textContent = BOOTSTRAP_FAILURE_COPY.reload;
  reloadButton.addEventListener('click', () => window.location.reload());
  actions.append(reloadButton);

  content.append(message, actions);
  container.append(header, content);
  host.append(container);
}
