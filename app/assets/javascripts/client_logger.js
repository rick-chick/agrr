// 開発環境専用: クライアント側のconsole.logをサーバーに送信
// パフォーマンス最適化版：バッチ送信 + レベルフィルタ
(function() {
  'use strict';
  
  // 開発環境でのみ動作
  if (window.location.hostname !== 'localhost' && window.location.hostname !== '127.0.0.1') {
    return;
  }

  // 設定
  const CONFIG = {
    batchInterval: 2000,        // 2秒ごとにまとめて送信
    maxBatchSize: 50,           // 最大50件まで溜める
    onlyErrorsAndWarnings: true, // trueならwarn/errorのみ送信（logは送信しない）
  };

  // オリジナルのconsoleメソッドを保存
  const originalLog = console.log;
  const originalWarn = console.warn;
  const originalError = console.error;
  const originalInfo = console.info;
  const originalDebug = console.debug;

  // ログキュー
  let logQueue = [];
  let flushTimer = null;

  // サーバーにログをバッチ送信する関数
  function flushLogs() {
    if (logQueue.length === 0) return;

    const logsToSend = logQueue.splice(0, CONFIG.maxBatchSize);
    
    fetch('/dev/client_logs', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'X-CSRF-Token': document.querySelector('meta[name="csrf-token"]')?.getAttribute('content') || ''
      },
      body: JSON.stringify({
        batch: true,
        logs: logsToSend
      })
    }).catch(() => {
      // サーバーへの送信エラーは無視（無限ループを避けるため）
    });

    // まだログが残っていれば再度送信
    if (logQueue.length > 0) {
      setTimeout(flushLogs, 100);
    }
  }

  // ログをキューに追加
  function queueLog(level, args) {
    // フィルタ: logとinfoとdebugは送信しない（設定による）
    if (CONFIG.onlyErrorsAndWarnings && ['log', 'info', 'debug'].includes(level)) {
      return;
    }

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

    logQueue.push({
      level: level,
      message: message,
      stack_trace: stackTrace,
      url: window.location.href,
      user_agent: navigator.userAgent,
      timestamp: new Date().toISOString()
    });

    // バッチサイズに達したら即座に送信
    if (logQueue.length >= CONFIG.maxBatchSize) {
      if (flushTimer) clearTimeout(flushTimer);
      flushLogs();
    } else {
      // タイマーをリセット
      if (flushTimer) clearTimeout(flushTimer);
      flushTimer = setTimeout(flushLogs, CONFIG.batchInterval);
    }
  }

  // console.logをオーバーライド（送信しない）
  console.log = function(...args) {
    originalLog.apply(console, args);
    queueLog('log', args);
  };

  console.warn = function(...args) {
    originalWarn.apply(console, args);
    queueLog('warn', args);
  };

  console.error = function(...args) {
    originalError.apply(console, args);
    queueLog('error', args);
  };

  console.info = function(...args) {
    originalInfo.apply(console, args);
    queueLog('info', args);
  };

  console.debug = function(...args) {
    originalDebug.apply(console, args);
    queueLog('debug', args);
  };

  // 未処理のエラーをキャッチ
  window.addEventListener('error', function(event) {
    queueLog('error', [
      `Uncaught Error: ${event.message}`,
      `at ${event.filename}:${event.lineno}:${event.colno}`,
      event.error?.stack || ''
    ]);
  });

  // Promise の reject をキャッチ
  window.addEventListener('unhandledrejection', function(event) {
    queueLog('error', [
      `Unhandled Promise Rejection: ${event.reason}`,
      event.reason?.stack || ''
    ]);
  });

  // ページ離脱時に残りのログを送信
  window.addEventListener('beforeunload', function() {
    if (logQueue.length > 0) {
      flushLogs();
    }
  });

  // ロガー初期化完了を通知
  const filterMsg = CONFIG.onlyErrorsAndWarnings ? ' (warn/error only)' : '';
  originalLog(`[Client Logger] Server-side logging enabled${filterMsg} - batch: ${CONFIG.batchInterval}ms`);
})();

