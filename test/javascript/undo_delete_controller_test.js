/**
 * @jest-environment jsdom
 */

import { Application } from "@hotwired/stimulus"
import UndoDeleteController from "../../app/javascript/controllers/undo_delete_controller"

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

describe("UndoDeleteController", () => {
  let application

  beforeEach(() => {
    document.body.innerHTML = `
      <div id="record-1" data-undo-delete-record>
        <a href="/plans/1"
           data-controller="undo-delete"
           data-action="click->undo-delete#submit"
           data-undo-delete-url-value="/plans/1"
           data-undo-delete-message-value="削除しました"
           data-undo-delete-redirect-url-value="/plans">
          削除
        </a>
      </div>
    `
    setCSRFToken("csrf-token-undo")
    global.fetch = jest.fn()
    application = Application.start()
    application.register("undo-delete", UndoDeleteController)
  })

  afterEach(() => {
    application?.stop()
    document.body.innerHTML = ""
    global.fetch.mockReset()
  })

  test("undo_token が欠落するレスポンスではDOMを非表示にしない（エラーをディスパッチ）", async () => {
    const link = document.querySelector("[data-controller='undo-delete']")
    const record = document.getElementById("record-1")
    const errorListener = jest.fn()
    window.addEventListener("undo:error", errorListener)

    // サーバーは ok だが undo_token を返さない
    global.fetch.mockResolvedValue({
      ok: true,
      json: jest.fn().mockResolvedValue({
        toast_message: "削除しました（取り消し不可）"
        // undo_token: missing
      })
    })

    // クリック → submit
    const clickEvent = new MouseEvent("click", { bubbles: true })
    link.dispatchEvent(clickEvent)

    await flushPromises()
    await flushPromises()

    // 欠落時はDOMを隠さない
    expect(record.classList.contains("undo-delete--hidden")).toBe(false)
    // エラーイベントが飛ぶ
    expect(errorListener).toHaveBeenCalled()
  })
})

/**
 * @jest-environment jsdom
 */
