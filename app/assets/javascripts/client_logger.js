// 開発環境専用: クライアント側のconsole.logをサーバーに送信
(function() {
  'use strict';
  
  // 開発環境でのみ動作
  if (window.location.hostname !== 'localhost' && window.location.hostname !== '127.0.0.1') {
    return;
  }

  // オリジナルのconsoleメソッドを保存
  const originalLog = console.log;
  const originalWarn = console.warn;
  const originalError = console.error;
  const originalInfo = console.info;
  const originalDebug = console.debug;

  // サーバーにログを送信する関数
  function sendLogToServer(level, args) {
    // ログメッセージを文字列化
    const message = Array.from(args).map(arg => {
      if (typeof arg === 'object') {
        try {
          return JSON.stringify(arg, null, 2);
        } catch (e) {
          return String(arg);
        }
      }
      return String(arg);
    }).join(' ');

    // スタックトレースを取得（エラーの場合）
    let stackTrace = '';
    if (level === 'error') {
      const error = new Error();
      stackTrace = error.stack || '';
    }

    // サーバーに送信（非同期、エラーは無視）
    fetch('/dev/client_logs', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'X-CSRF-Token': document.querySelector('meta[name="csrf-token"]')?.getAttribute('content') || ''
      },
      body: JSON.stringify({
        level: level,
        message: message,
        stack_trace: stackTrace,
        url: window.location.href,
        user_agent: navigator.userAgent,
        timestamp: new Date().toISOString()
      })
    }).catch(() => {
      // サーバーへの送信エラーは無視（無限ループを避けるため）
    });
  }

  // console.logをオーバーライド
  console.log = function(...args) {
    originalLog.apply(console, args);
    sendLogToServer('log', args);
  };

  console.warn = function(...args) {
    originalWarn.apply(console, args);
    sendLogToServer('warn', args);
  };

  console.error = function(...args) {
    originalError.apply(console, args);
    sendLogToServer('error', args);
  };

  console.info = function(...args) {
    originalInfo.apply(console, args);
    sendLogToServer('info', args);
  };

  console.debug = function(...args) {
    originalDebug.apply(console, args);
    sendLogToServer('debug', args);
  };

  // 未処理のエラーをキャッチ
  window.addEventListener('error', function(event) {
    sendLogToServer('error', [
      `Uncaught Error: ${event.message}`,
      `at ${event.filename}:${event.lineno}:${event.colno}`,
      event.error?.stack || ''
    ]);
  });

  // Promise の reject をキャッチ
  window.addEventListener('unhandledrejection', function(event) {
    sendLogToServer('error', [
      `Unhandled Promise Rejection: ${event.reason}`,
      event.reason?.stack || ''
    ]);
  });

  // ロガー初期化完了を通知
  originalLog('[Client Logger] Server-side logging enabled for development');
})();

