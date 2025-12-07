/**
 * @jest-environment jsdom
 */

import { Application } from "@hotwired/stimulus"
import CopyToClipboardController from "../../app/javascript/controllers/copy_to_clipboard_controller"

describe("CopyToClipboardController i18n", () => {
  let application
  let button
  let source
  let originalExecCommand

  beforeEach(() => {
    document.body.innerHTML = `
      <div id="js-i18n"
           data-copy-to-clipboard-success="copied!"
           data-copy-to-clipboard-failure="copy failed"
           data-copy-to-clipboard-fallback="please copy manually">
      </div>
      <div data-controller="copy-to-clipboard">
        <input type="text" value="secret" data-copy-to-clipboard-target="source" />
        <button type="button"
                data-action="click->copy-to-clipboard#copy"
                data-copy-to-clipboard-target="button"
                data-copy-to-clipboard-success-label="copied!"
                data-copy-to-clipboard-failure-label="copy failed"
                data-copy-to-clipboard-fallback-label="please copy manually">
          Copy
        </button>
      </div>
    `

    originalExecCommand = document.execCommand
    application = Application.start()
    application.register("copy-to-clipboard", CopyToClipboardController)

    source = document.querySelector("[data-copy-to-clipboard-target='source']")
    button = document.querySelector("[data-copy-to-clipboard-target='button']")
  })

  afterEach(() => {
    document.execCommand = originalExecCommand
    application?.stop()
    document.body.innerHTML = ""
  })

  test("コピー成功時にi18nの成功メッセージを使用する", () => {
    const execSpy = jest.fn(() => true)
    document.execCommand = execSpy

    button.click()

    expect(execSpy).toHaveBeenCalledWith("copy")
    expect(button.textContent).toBe("copied!")
  })

  test("コピー失敗時にi18nのエラーメッセージでalertする", () => {
    const alertSpy = jest.spyOn(window, "alert").mockImplementation(() => {})
    document.execCommand = jest.fn(() => {
      throw new Error("copy failed")
    })

    button.click()

    expect(alertSpy).toHaveBeenCalledWith("copy failed\nplease copy manually")
    alertSpy.mockRestore()
  })
})

