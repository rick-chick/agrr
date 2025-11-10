/**
 * @jest-environment jsdom
 */

import { Application } from "@hotwired/stimulus"
import UndoDeleteController from "../../app/javascript/controllers/undo_delete_controller"

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

const startUndoDeleteController = () => {
  const application = Application.start()
  application.register("undo-delete", UndoDeleteController)
  const element = document.querySelector("[data-controller='undo-delete']")

  return { application, element }
}

describe("UndoDeleteController", () => {
  let application
  let element

  beforeEach(() => {
    document.body.innerHTML = `
      <div id="record-42" data-undo-delete-record>
        <button
          type="button"
          data-controller="undo-delete"
          data-undo-delete-url-value="/records/42"
          data-action="click->undo-delete#submit"
        >
          削除
        </button>
      </div>
    `

    setCSRFToken("test-csrf-token")
    global.fetch = jest.fn()

    ;({ application, element } = startUndoDeleteController())
  })

  afterEach(() => {
    application?.stop()
    document.body.innerHTML = ""
    global.fetch = originalFetch
  })

  test("削除成功時に undo:show イベントをディスパッチする", async () => {
    const responseBody = {
      undo_token: "token-123",
      undo_path: "/records/42/undo",
      toast_message: "削除を元に戻しますか？",
      undo_deadline: "2025-11-09T12:00:00Z",
      redirect_path: "/records"
    }

    const jsonMock = jest.fn().mockResolvedValue(responseBody)
    global.fetch.mockResolvedValue({
      ok: true,
      json: jsonMock
    })

    const undoShowListener = jest.fn()
    window.addEventListener("undo:show", undoShowListener, { once: true })

    element.click()

    await flushPromises()
    await flushPromises()

    expect(global.fetch).toHaveBeenCalledTimes(1)

    const [url, options] = global.fetch.mock.calls[0]
    expect(url).toBe("/records/42")
    expect(options).toMatchObject({ method: "DELETE" })

    const headers =
      options.headers instanceof Headers ? Object.fromEntries(options.headers.entries()) : options.headers

    expect(headers["Content-Type"]).toBe("application/json")
    expect(headers["X-CSRF-Token"]).toBe("test-csrf-token")

    expect(jsonMock).toHaveBeenCalledTimes(1)

    expect(undoShowListener).toHaveBeenCalledTimes(1)
    const event = undoShowListener.mock.calls[0][0]

    expect(event).toBeInstanceOf(CustomEvent)
    expect(event.type).toBe("undo:show")
    expect(event.detail).toEqual(expect.objectContaining(responseBody))

    const recordElement = document.getElementById("record-42")
    expect(recordElement).not.toBeNull()
    expect(recordElement?.classList.contains("undo-delete--hidden")).toBe(true)
    expect(recordElement?.dataset.undoDeleteToken).toBe("token-123")
  })

  test("削除失敗時に undo:error イベントをディスパッチする", async () => {
    global.fetch.mockResolvedValue({
      ok: false,
      status: 422
    })

    const undoErrorListener = jest.fn()
    window.addEventListener("undo:error", undoErrorListener, { once: true })

    element.click()

    await flushPromises()
    await flushPromises()

    expect(global.fetch).toHaveBeenCalledTimes(1)
    expect(undoErrorListener).toHaveBeenCalledTimes(1)

    const event = undoErrorListener.mock.calls[0][0]
    expect(event).toBeInstanceOf(CustomEvent)
    expect(event.type).toBe("undo:error")
  })

  test("undo:restored イベントでレコードが再表示される", async () => {
    document.getElementById("record-42")?.classList.add("undo-delete--hidden")
    document.getElementById("record-42")?.setAttribute("data-undo-delete-token", "token-abc")

    window.dispatchEvent(new CustomEvent("undo:restored", { detail: { undo_token: "token-abc" } }))

    const recordElement = document.getElementById("record-42")
    expect(recordElement?.classList.contains("undo-delete--hidden")).toBe(false)
    expect(recordElement?.dataset.undoDeleteToken).toBeUndefined()
  })
})

