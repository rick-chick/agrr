import { Controller } from "@hotwired/stimulus"

const DEFAULT_METHOD = "DELETE"

const HIDDEN_CLASS = "undo-delete--hidden"

export default class extends Controller {
  static values = {
    url: String,
    method: { type: String, default: DEFAULT_METHOD },
    message: String,
    autoHideAfter: Number,
    redirectUrl: String
  }

  connect() {
    this.handleRestored = this.handleRestored.bind(this)
    window.addEventListener("undo:restored", this.handleRestored)
  }

  disconnect() {
    window.removeEventListener("undo:restored", this.handleRestored)
  }

  submit(event) {
    event.preventDefault()

    if (this.loading) return

    this.loading = true
    this.performDelete()
  }

  async performDelete() {
    const url = this.urlValue || this.element.getAttribute("href") || this.element.dataset.url

    if (!url) {
      this.dispatchError({ error: "Missing undo delete URL" })
      this.loading = false
      return
    }

    try {
      const response = await fetch(url, {
        method: this.methodValue?.toUpperCase() || DEFAULT_METHOD,
        headers: this.headers,
        body: JSON.stringify({})
      })

      if (!response.ok) {
        this.dispatchError({ status: response.status })
        return
      }

      const payload = await response.json()

      const detail = { ...payload }

      if (!detail.toast_message && this.hasMessageValue) {
        detail.toast_message = this.messageValue
      }

      if (!detail.auto_hide_after && this.hasAutoHideAfterValue) {
        detail.auto_hide_after = this.autoHideAfterValue
      }

      this.applyPostDelete(detail)
      window.dispatchEvent(new CustomEvent("undo:show", { detail }))
    } catch (error) {
      this.dispatchError({ error: error.message })
    } finally {
      this.loading = false
    }
  }

  get headers() {
    const headers = {
      "Content-Type": "application/json",
      Accept: "application/json"
    }

    const token = this.csrfToken
    if (token) {
      headers["X-CSRF-Token"] = token
    }

    return headers
  }

  get csrfToken() {
    const meta = document.querySelector("meta[name='csrf-token']")
    return meta?.getAttribute("content")
  }

  dispatchError(detail) {
    window.dispatchEvent(new CustomEvent("undo:error", { detail }))
  }

  applyPostDelete(detail) {
    const recordElement = this.recordElement
    const recordId = recordElement?.id
    const undoToken = typeof detail.undo_token === "string" ? detail.undo_token.trim() : detail.undo_token

    if (recordElement) {
      recordElement.classList.add(HIDDEN_CLASS)

      if (undoToken) {
        recordElement.dataset.undoDeleteToken = undoToken
      } else {
        console.warn("[UndoDelete] undo_token is missing or blank", {
          recordId,
          url: this.urlValue || this.element.dataset.url,
          response: detail
        })
        this.dispatchError({ error: "missing_undo_token", recordId })
      }
    }

    const redirectPath = detail.redirect_path || (this.hasRedirectUrlValue ? this.redirectUrlValue : null)
    if (!recordElement && redirectPath) {
      requestAnimationFrame(() => {
        window.location.href = redirectPath
      })
    }
  }

  handleRestored(event) {
    const token = event.detail?.undo_token
    if (!token) return

    const selector = `[data-undo-delete-token="${this.escapeSelector(token)}"]`
    const element = document.querySelector(selector)
    if (!element) return

    element.classList.remove(HIDDEN_CLASS)
    delete element.dataset.undoDeleteToken
  }

  get recordElement() {
    if (this._recordElement === undefined) {
      this._recordElement = this.element.closest("[data-undo-delete-record]")
    }
    return this._recordElement
  }

  escapeSelector(value) {
    if (typeof window !== "undefined" && window.CSS && typeof window.CSS.escape === "function") {
      return window.CSS.escape(value)
    }

    return String(value).replace(/([ !"#$%&'()*+,./:;<=>?@[\\\]^`{|}~])/g, "\\$1")
  }
}

