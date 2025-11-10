/**
 * @jest-environment jsdom
 */

import { Application } from "@hotwired/stimulus"
import UndoToastController from "../../app/javascript/controllers/undo_toast_controller"

const originalFetch = global.fetch

const flushPromises = () =>
  new Promise((resolve) => {
    if (typeof setImmediate === "function") {
      setImmediate(resolve)
    } else {
      setTimeout(resolve, 0)
    }
  })

const setCSRFToken = (token) => {
  let meta = document.querySelector('meta[name="csrf-token"]')
  if (!meta) {
    meta = document.createElement("meta")
    meta.setAttribute("name", "csrf-token")
    document.head.appendChild(meta)
  }
  meta.setAttribute("content", token)
}

const startUndoToastController = () => {
  const application = Application.start()
  application.register("undo-toast", UndoToastController)
  const element = document.querySelector("[data-controller='undo-toast']")
  const message = element.querySelector("[data-undo-toast-target='message']")
  const undoButton = element.querySelector("[data-undo-toast-target='undoButton']")
  const closeButton = element.querySelector("[data-undo-toast-target='closeButton']")

  return { application, element, message, undoButton, closeButton }
}

describe("UndoToastController", () => {
  let application
  let toastElement
  let messageElement
  let undoButton
  let closeButton

  beforeEach(() => {
    jest.useFakeTimers()
    document.body.innerHTML = `
      <div
        class="undo-toast hidden"
        data-controller="undo-toast"
        data-undo-toast-auto-hide-after-value="5000"
      >
        <p data-undo-toast-target="message"></p>
        <button
          type="button"
          data-undo-toast-target="undoButton"
          data-action="click->undo-toast#undo"
        >
          元に戻す
        </button>
        <button
          type="button"
          data-undo-toast-target="closeButton"
          data-action="click->undo-toast#close"
        >
          閉じる
        </button>
      </div>
    `

    setCSRFToken("toast-csrf-token")
    global.fetch = jest.fn()

    ;({ application, element: toastElement, message: messageElement, undoButton, closeButton } =
      startUndoToastController())
  })

  afterEach(() => {
    application?.stop()
    document.body.innerHTML = ""
    global.fetch = originalFetch
    jest.useRealTimers()
  })

  test("undo:show イベントでトーストが表示され情報を更新する", async () => {
    const detail = {
      undo_token: "token-abc",
      undo_path: "/records/undo",
      toast_message: "削除を取り消しますか？",
      undo_deadline: "2025-11-09T15:00:00Z",
      auto_hide_after: 3000
    }

    window.dispatchEvent(new CustomEvent("undo:show", { detail }))

    await flushPromises()

    expect(toastElement.classList.contains("hidden")).toBe(false)
    expect(messageElement.textContent).toBe(detail.toast_message)
    expect(undoButton.dataset.undoToken).toBe(detail.undo_token)
    expect(undoButton.dataset.undoPath).toBe(detail.undo_path)
    expect(toastElement.dataset.undoToastAutoHideAfterValue).toBe("3000")
  })

  test("Undo ボタンで復元リクエスト成功時に undo:restored をディスパッチしトーストを隠す", async () => {
    const detail = {
      undo_token: "token-success",
      undo_path: "/records/42/undo",
      toast_message: "削除を元に戻しました",
      undo_deadline: "2025-11-09T15:00:00Z"
    }

    global.fetch.mockResolvedValue({
      ok: true,
      json: jest.fn().mockResolvedValue({})
    })

    const restoredListener = jest.fn()
    window.addEventListener("undo:restored", restoredListener, { once: true })

    window.dispatchEvent(new CustomEvent("undo:show", { detail }))
    await flushPromises()

    undoButton.click()

    await flushPromises()
    await flushPromises()

    expect(global.fetch).toHaveBeenCalledTimes(1)

    const [url, options] = global.fetch.mock.calls[0]
    expect(url).toBe(detail.undo_path)
    expect(options).toMatchObject({ method: "POST" })

    const headers =
      options.headers instanceof Headers ? Object.fromEntries(options.headers.entries()) : options.headers

    expect(headers["Content-Type"]).toBe("application/json")
    expect(headers["X-CSRF-Token"]).toBe("toast-csrf-token")

    expect(restoredListener).toHaveBeenCalledTimes(1)
    expect(toastElement.classList.contains("hidden")).toBe(true)
  })

  test("auto_hide_after 経過後にトーストが自動的に隠れる", async () => {
    const detail = {
      undo_token: "token-auto-hide",
      undo_path: "/records/99/undo",
      toast_message: "自動的に閉じます",
      undo_deadline: "2025-11-09T16:00:00Z",
      auto_hide_after: 2000
    }

    window.dispatchEvent(new CustomEvent("undo:show", { detail }))
    await flushPromises()

    expect(toastElement.classList.contains("hidden")).toBe(false)

    jest.advanceTimersByTime(2000)
    await flushPromises()

    expect(toastElement.classList.contains("hidden")).toBe(true)
  })

  test("auto_hide_after が秒指定でもミリ秒に変換される", async () => {
    const detail = {
      undo_token: "token-seconds",
      undo_path: "/records/88/undo",
      toast_message: "5秒後に閉じます",
      undo_deadline: "2025-11-09T16:30:00Z",
      auto_hide_after: 5
    }

    window.dispatchEvent(new CustomEvent("undo:show", { detail }))
    await flushPromises()

    expect(toastElement.classList.contains("hidden")).toBe(false)

    jest.advanceTimersByTime(4900)
    await flushPromises()
    expect(toastElement.classList.contains("hidden")).toBe(false)

    jest.advanceTimersByTime(200)
    await flushPromises()
    expect(toastElement.classList.contains("hidden")).toBe(true)
  })

  test("復元リクエストが失敗した場合 undo:error をディスパッチしトーストは表示されたまま", async () => {
    const detail = {
      undo_token: "token-fail",
      undo_path: "/records/404/undo",
      toast_message: "失敗しました",
      undo_deadline: "2025-11-09T17:00:00Z"
    }

    global.fetch.mockResolvedValue({
      ok: false,
      status: 500
    })

    const errorListener = jest.fn()
    window.addEventListener("undo:error", errorListener, { once: true })

    window.dispatchEvent(new CustomEvent("undo:show", { detail }))
    await flushPromises()

    undoButton.click()

    await flushPromises()
    await flushPromises()

    expect(global.fetch).toHaveBeenCalledTimes(1)
    expect(errorListener).toHaveBeenCalledTimes(1)
    expect(toastElement.classList.contains("hidden")).toBe(false)
  })
})

