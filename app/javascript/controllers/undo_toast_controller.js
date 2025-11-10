import { Controller } from "@hotwired/stimulus"

const DEFAULT_AUTO_HIDE = 5000

export default class extends Controller {
  static targets = ["message", "undoButton", "closeButton"]
  static values = { autoHideAfter: { type: Number, default: DEFAULT_AUTO_HIDE } }

  connect() {
    this.handleShow = this.handleShowEvent.bind(this)
    window.addEventListener("undo:show", this.handleShow)
  }

  disconnect() {
    window.removeEventListener("undo:show", this.handleShow)
    this.clearTimer()
  }

  async undo(event) {
    event.preventDefault()

    const undoPath = this.undoButtonTarget.dataset.undoPath
    const undoToken = this.undoButtonTarget.dataset.undoToken

    if (!undoPath || !undoToken) {
      window.dispatchEvent(new CustomEvent("undo:error", { detail: { error: "Missing undo parameters" } }))
      return
    }

    try {
      const response = await fetch(undoPath, {
        method: "POST",
        headers: this.headers,
        body: JSON.stringify({ undo_token: undoToken })
      })

      if (!response.ok) {
        window.dispatchEvent(new CustomEvent("undo:error", { detail: { status: response.status } }))
        return
      }

      await response.json()
      window.dispatchEvent(new CustomEvent("undo:restored", { detail: { undo_token: undoToken } }))
      this.close()
    } catch (error) {
      window.dispatchEvent(new CustomEvent("undo:error", { detail: { error: error.message } }))
    }
  }

  close(event) {
    event?.preventDefault()
    this.element.classList.add("hidden")
    this.undoButtonTarget.dataset.undoToken = ""
    this.undoButtonTarget.dataset.undoPath = ""
    this.clearTimer()
  }

  handleShowEvent(event) {
    const detail = event.detail || {}
    const undoPath = detail.undo_path || ""
    const undoToken = typeof detail.undo_token === "string" ? detail.undo_token.trim() : detail.undo_token

    this.messageTarget.textContent = detail.toast_message || ""
    this.undoButtonTarget.dataset.undoPath = undoPath
    if (undoToken) {
      this.undoButtonTarget.dataset.undoToken = undoToken
    } else {
      this.undoButtonTarget.dataset.undoToken = ""
      console.warn("[UndoToast] Received payload without undo_token", { detail })
    }

    const autoHideMs = this.normalizeDelay(detail.auto_hide_after ?? this.autoHideAfterValue)
    this.element.classList.remove("hidden")

    this.clearTimer()
    if (autoHideMs && autoHideMs > 0) {
      this.timer = setTimeout(() => this.close(), autoHideMs)
    }
  }

  clearTimer() {
    if (this.timer) {
      clearTimeout(this.timer)
      this.timer = null
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

  normalizeDelay(value) {
    if (value == null) return this.autoHideAfterValue

    const numeric = Number(value)
    if (Number.isNaN(numeric) || numeric <= 0) return 0

    // 値が秒単位と推測される場合（10未満など）にミリ秒へ変換
    if (numeric < 1000) {
      return Math.round(numeric * 1000)
    }

    return Math.round(numeric)
  }
}

