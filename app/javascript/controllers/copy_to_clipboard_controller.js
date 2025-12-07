import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["source", "button"]

  copy(event) {
    event.preventDefault()
    
    const text = this.sourceTarget.value
    
    if (navigator.clipboard && navigator.clipboard.writeText) {
      navigator.clipboard.writeText(text).then(() => {
        this.showSuccess()
      }).catch(() => {
        this.fallbackCopy(text)
      })
    } else {
      this.fallbackCopy(text)
    }
  }

  fallbackCopy(text) {
    // フォールバック: テキストエリアを作成してコピー
    const textArea = document.createElement("textarea")
    textArea.value = text
    textArea.style.position = "fixed"
    textArea.style.left = "-999999px"
    document.body.appendChild(textArea)
    textArea.focus()
    textArea.select()
    
    try {
      document.execCommand('copy')
      this.showSuccess()
    } catch (err) {
      console.error('コピーに失敗しました:', err)
      const failure = this.translate('Failure', 'コピーに失敗しました。')
      const fallback = this.translate('Fallback', '手動でコピーしてください。')
      alert(`${failure}\n${fallback}`)
    }
    
    document.body.removeChild(textArea)
  }

  showSuccess() {
    const originalText = this.buttonTarget.textContent
    this.buttonTarget.textContent = this.translate('Success', 'コピーしました！')
    this.buttonTarget.classList.add("btn-success")
    this.buttonTarget.classList.remove("btn-secondary")
    
    setTimeout(() => {
      this.buttonTarget.textContent = originalText
      this.buttonTarget.classList.remove("btn-success")
      this.buttonTarget.classList.add("btn-secondary")
    }, 2000)
  }

  translate(suffix, fallback) {
    const datasetKey = `copyToClipboard${suffix}Label`
    const datasetValue = this.buttonTarget?.dataset?.[datasetKey]
    if (datasetValue) return datasetValue
    if (typeof getI18nMessage === "function") {
      return getI18nMessage(`copyToClipboard${suffix}`, fallback)
    }
    return fallback
  }
}
