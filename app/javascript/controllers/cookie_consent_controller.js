import { Controller } from "@hotwired/stimulus"

// Cookie consent modal controller
// - Handles initial state based on localStorage
// - Updates consent via gtag/dataLayer
// - Triggers AdSense lazy load when granted
export default class extends Controller {
  static targets = ["accept", "reject"]

  connect() {
    this.storageKey = "cookieConsentStatus"
    this._bindPageRestoreHandlers()
    this._showIfNeeded()
  }

  disconnect() {
    this._unbindPageRestoreHandlers()
    this._releaseFocus()
  }

  accept(event) {
    event.preventDefault()
    this._updateConsent(true)
  }

  reject(event) {
    event.preventDefault()
    this._updateConsent(false)
  }

  // ========= Private =========
  _showIfNeeded() {
    const saved = this._getStoredConsent()
    if (saved === "granted" || saved === "denied") {
      this._applyConsent(saved === "granted")
      this._hide()
      return
    }
    this.element.classList.remove("hidden")
    this._trapFocus()
  }

  _getStoredConsent() {
    try {
      return localStorage.getItem(this.storageKey)
    } catch (e) {
      return null
    }
  }

  _setStoredConsent(value) {
    try {
      localStorage.setItem(this.storageKey, value)
    } catch (e) {
      // ignore
    }
  }

  _updateConsent(granted) {
    const value = granted ? "granted" : "denied"
    this._setStoredConsent(value)
    this._applyConsent(granted)
    this._hide()
  }

  _applyConsent(granted) {
    if (typeof gtag === "function") {
      gtag("consent", "update", {
        ad_storage: granted ? "granted" : "denied",
        ad_user_data: granted ? "granted" : "denied",
        ad_personalization: granted ? "granted" : "denied",
        analytics_storage: granted ? "granted" : "denied",
        functionality_storage: "granted",
        security_storage: "granted",
      })
    } else {
      window.dataLayer = window.dataLayer || []
      window.dataLayer.push([
        "consent",
        "update",
        {
          ad_storage: granted ? "granted" : "denied",
          ad_user_data: granted ? "granted" : "denied",
          ad_personalization: granted ? "granted" : "denied",
          analytics_storage: granted ? "granted" : "denied",
          functionality_storage: "granted",
          security_storage: "granted",
        },
      ])
    }

    if (granted && typeof window.loadAdSense === "function") {
      window.loadAdSense()
    }
  }

  _hide() {
    this.element.classList.add("hidden")
    this._releaseFocus()
  }

  _bindPageRestoreHandlers() {
    this._onPageShow = this._onPageShow || (() => this._showIfNeeded())
    this._onTurboRender = this._onTurboRender || (() => this._showIfNeeded())
    this._onTurboBeforeCache = this._onTurboBeforeCache || (() => this._releaseFocus())
    window.addEventListener("pageshow", this._onPageShow)
    document.addEventListener("turbo:render", this._onTurboRender)
    document.addEventListener("turbo:before-cache", this._onTurboBeforeCache)
  }

  _unbindPageRestoreHandlers() {
    if (this._onPageShow) window.removeEventListener("pageshow", this._onPageShow)
    if (this._onTurboRender) document.removeEventListener("turbo:render", this._onTurboRender)
    if (this._onTurboBeforeCache) document.removeEventListener("turbo:before-cache", this._onTurboBeforeCache)
  }

  // Minimal focus trap for modal
  _trapFocus() {
    this.previousActive = document.activeElement
    const focusables = this.element.querySelectorAll(
      'button, [href], input, select, textarea, [tabindex]:not([tabindex="-1"])'
    )
    if (focusables.length > 0) {
      focusables[0].focus()
    } else {
      this.element.focus?.()
    }
    this._keydownHandler = (e) => {
      if (e.key === "Tab") {
        const first = focusables[0]
        const last = focusables[focusables.length - 1]
        if (e.shiftKey && document.activeElement === first) {
          e.preventDefault()
          last.focus()
        } else if (!e.shiftKey && document.activeElement === last) {
          e.preventDefault()
          first.focus()
        }
      }
      // Do not close on Escape for policy compliance; we keep modal until decision
    }
    document.addEventListener("keydown", this._keydownHandler)
  }

  _releaseFocus() {
    if (this._keydownHandler) {
      document.removeEventListener("keydown", this._keydownHandler)
    }
    if (this.previousActive && typeof this.previousActive.focus === "function") {
      this.previousActive.focus()
    }
  }
}

