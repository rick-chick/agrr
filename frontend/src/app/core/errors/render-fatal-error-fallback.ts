import { resolveInitialAppLang, type AppLang } from '../app-locale';

export type FatalErrorFallbackKind = 'bootstrap' | 'runtime';

export type FatalErrorFallbackOptions = {
  kind: FatalErrorFallbackKind;
  lang?: AppLang;
};

type FallbackCopy = {
  title: string;
  message: string;
  reload: string;
};

const COPY_BY_LANG: Record<AppLang, Record<FatalErrorFallbackKind, FallbackCopy>> = {
  ja: {
    bootstrap: {
      title: 'アプリを起動できませんでした',
      message:
        'ページを再読み込みしてください。問題が続く場合はしばらくしてからお試しください。',
      reload: '再読み込み'
    },
    runtime: {
      title: '予期しないエラーが発生しました',
      message:
        'ページを再読み込みしてください。問題が続く場合はしばらくしてからお試しください。',
      reload: '再読み込み'
    }
  },
  en: {
    bootstrap: {
      title: 'Unable to start the app',
      message: 'Please reload the page. If the problem persists, try again later.',
      reload: 'Reload'
    },
    runtime: {
      title: 'An unexpected error occurred',
      message: 'Please reload the page. If the problem persists, try again later.',
      reload: 'Reload'
    }
  },
  in: {
    bootstrap: {
      title: 'ऐप शुरू नहीं हो सका',
      message:
        'कृपया पृष्ठ पुनः लोड करें। समस्या बनी रहे तो थोड़ी देर बाद फिर कोशिश करें।',
      reload: 'पुनः लोड करें'
    },
    runtime: {
      title: 'अप्रत्याशित त्रुटि हुई',
      message:
        'कृपया पृष्ठ पुनः लोड करें। समस्या बनी रहे तो थोड़ी देर बाद फिर कोशिश करें।',
      reload: 'पुनः लोड करें'
    }
  }
};

export function resolveFatalErrorCopy(
  kind: FatalErrorFallbackKind,
  lang: AppLang = resolveInitialAppLang()
): FallbackCopy {
  return COPY_BY_LANG[lang][kind];
}

export const FATAL_ERROR_FALLBACK_ROOT_ID = 'agrr-fatal-error-fallback';

/**
 * Imperative DOM fallback when Angular bootstrap or runtime recovery is unavailable.
 * Bypasses Shell/L1 error pattern intentionally — TranslateService may not be ready.
 */
export function renderFatalErrorFallback(
  host: HTMLElement,
  options: FatalErrorFallbackOptions
): void {
  const copy = resolveFatalErrorCopy(options.kind, options.lang);
  host.replaceChildren();

  const root = document.createElement('div');
  root.id = FATAL_ERROR_FALLBACK_ROOT_ID;
  root.setAttribute('role', 'alert');
  root.className = 'page-content-container';

  const header = document.createElement('div');
  header.className = 'page-header';

  const title = document.createElement('h1');
  title.className = 'page-title';
  title.textContent = copy.title;
  header.appendChild(title);

  const content = document.createElement('div');
  content.className = 'page-content';

  const message = document.createElement('p');
  message.className = 'page-section-content';
  message.textContent = copy.message;
  content.appendChild(message);

  const actions = document.createElement('p');
  const button = document.createElement('button');
  button.type = 'button';
  button.className = 'primary-button';
  button.textContent = copy.reload;
  button.addEventListener('click', () => {
    window.location.reload();
  });
  actions.appendChild(button);
  content.appendChild(actions);

  root.appendChild(header);
  root.appendChild(content);
  host.appendChild(root);
}
