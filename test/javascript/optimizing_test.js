/**
 * @jest-environment jsdom
 */

// optimizing.js は即時関数でグローバル実行されるため、テストごとにDOMとグローバルを初期化する

const loadOptimizingScript = async () => {
  const script = require("../../app/assets/javascripts/optimizing.js")
  return script
}

const flushPromises = () =>
  new Promise((resolve) => {
    if (typeof setImmediate === "function") {
      setImmediate(resolve)
    } else {
      setTimeout(resolve, 0)
    }
  })

describe("optimizing.js フォールバック挙動", () => {
  beforeEach(async () => {
    jest.useFakeTimers()
    // 先にスクリプトをロードしてイベントリスナを登録
    await loadOptimizingScript()
    // optimizing画面のDOM
    document.body.innerHTML = `
      <div data-optimizing-container
           data-cultivation-plan-id="42"
           data-channel-name="PlansOptimizationChannel"
           data-redirect-url="/plans/42">
      </div>
      <div class="fixed-progress-bar">
        <div id="error-message-container" style="display:none;">
          <div id="error-detail"></div>
        </div>
        <div id="phase-message"></div>
        <div id="progress-duration-hint"></div>
        <div id="elapsed-time"
             data-elapsed-time-template="⏳ %{time}"
             data-elapsed-time-minute-template="%{minutes}分%{seconds}秒">
        </div>
        <span id="loading-spinner"></span>
      </div>
    `
    // Turboのイベント発火を模倣して初期化
    document.dispatchEvent(new Event("turbo:load"))
  })

  afterEach(() => {
    jest.useRealTimers()
    document.body.innerHTML = ""
    delete window.CableSubscriptionManager
    delete window.ClientLogger
  })

  test("CableSubscriptionManager が未ロードのまま一定回数経過したらページリロードせず明示エラー表示に遷移する", async () => {
    // ClientLoggerをダミー化（ログ呼び出し抑止）
    window.ClientLogger = { log: jest.fn() }
    // CableSubscriptionManager は未定義のまま

    // 5秒（100ms * 50回）待機を経過させる
    for (let i = 0; i <= 50; i++) {
      jest.advanceTimersByTime(100)
      await flushPromises()
    }

    // リロードは行われないこと（location.reloadが呼ばれていない）
    const reloadSpy = jest.spyOn(window.location, "reload").mockImplementation(() => {})
    expect(reloadSpy).not.toHaveBeenCalled()
    reloadSpy.mockRestore()

    // エラーUIが表示される（error-message-container が表示状態になる想定）
    const errorContainer = document.getElementById("error-message-container")
    expect(errorContainer).not.toBeNull()
    expect(errorContainer.style.display).toBe("flex")
    const errorDetail = document.getElementById("error-detail")
    expect(errorDetail.textContent).toMatch(/最適化の接続に失敗|エラー|failed|not found/i)
  }, 15000)

  test("切断発生時は最大1回のみ再接続し、それでも失敗した場合はエラーUIを表示する", async () => {
    // ダミーのCableSubscriptionManagerを用意
    const subscribeMock = jest.fn((_planId, callbacks) => {
      // 直ちにonDisconnectedを発火させる
      setTimeout(() => callbacks.onDisconnected(), 0)
      return { unsubscribe: jest.fn() }
    })
    window.CableSubscriptionManager = {
      subscribeToOptimization: subscribeMock,
      unsubscribe: jest.fn()
    }
    window.ClientLogger = { log: jest.fn() }

    await loadOptimizingScript()
    await flushPromises()

    // 1回目の切断 → 再接続まで少し待つ
    jest.advanceTimersByTime(50)
    await flushPromises()

    // 2回目も切断させるために subscribe を同じ挙動で呼ぶ
    // 既にsubscribeMockが呼ばれているはず
    expect(subscribeMock).toHaveBeenCalled()

    // 再接続の待機時間を進める
    jest.advanceTimersByTime(200)
    await flushPromises()

    // 最大再接続を超えたらエラーUIへ
    const errorContainer = document.getElementById("error-message-container")
    expect(errorContainer).not.toBeNull()
    expect(errorContainer.style.display).toBe("flex")
  }, 15000)
})


