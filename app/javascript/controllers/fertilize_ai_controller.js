import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="fertilize-ai"
export default class extends Controller {
  connect() {
    console.log('[FertilizeAiController] connect() called')
    this.button = this.element
    this.statusDiv = document.getElementById('ai-save-status')
    this.nameField = document.querySelector('input[name="fertilize[name]"]')
    this.adPopup = document.getElementById('ad-popup-overlay')
    
    console.log('[FertilizeAiController] button:', this.button)
    console.log('[FertilizeAiController] nameField:', this.nameField)
    console.log('[FertilizeAiController] statusDiv:', this.statusDiv)
    console.log('[FertilizeAiController] adPopup:', this.adPopup)
    
    if (!this.button) {
      console.error('[FertilizeAiController] Button element not found!')
      return
    }
    
    this.button.addEventListener('click', this.saveFertilize.bind(this))
    console.log('[FertilizeAiController] Event listener attached')
  }

  async saveFertilize(event) {
    console.log('[FertilizeAiController] saveFertilize() called', event)
    event.preventDefault()
    
    const fertilizeName = this.nameField?.value?.trim()
    console.log('[FertilizeAiController] fertilizeName:', fertilizeName)
    
    // Validation
    if (!fertilizeName) {
      console.log('[FertilizeAiController] Validation failed: no fertilize name')
      this.showStatus(this.element.dataset.enterName || '肥料名を入力してください', 'error')
      return
    }
    
    // Disable button and show loading
    this.button.disabled = true
    this.button.textContent = this.element.dataset.buttonFetching || '🤖 AIで情報を取得中...'
    this.showStatus(this.element.dataset.fetching || 'AIで肥料情報を取得しています...', 'info')
    
    // Show advertisement popup
    this.showAdPopup()
    
    try {
      const csrfToken = document.querySelector('[name="csrf-token"]')?.content
      
      // AI Create APIを呼び出し（agrrコマンドで情報取得 + 保存）
      const response = await fetch('/api/v1/fertilizes/ai_create', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'X-CSRF-Token': csrfToken
        },
        body: JSON.stringify({ 
          name: fertilizeName
        })
      })
      
      const data = await response.json()
      
      if (response.ok) {
        // 成功時：広告を閉じて肥料詳細画面に遷移
        this.showStatus((this.element.dataset.createdSuccess || '✓ 肥料「%{name}」の情報を取得して保存しました！').replace('%{name}', data.fertilize_name), 'success')
        
        // Wait a moment to show success message, then redirect
        setTimeout(() => {
          this.hideAdPopup()
          window.location.href = `/fertilizes/${data.fertilize_id}`
        }, 1500)
      } else {
        this.hideAdPopup()
        this.showStatus(`エラー: ${data.error || (this.element.dataset.fetchFailed || '肥料情報の取得に失敗しました')}` , 'error')
        this.resetButton()
      }
    } catch (error) {
      console.error('Error in AI fertilize creation:', error)
      this.hideAdPopup()
      this.showStatus(this.element.dataset.networkError || 'ネットワークエラーが発生しました', 'error')
      this.resetButton()
    }
  }
  
  showStatus(message, type) {
    if (this.statusDiv) {
      this.statusDiv.textContent = message
      this.statusDiv.style.display = 'block'
      this.statusDiv.className = `form-text ai-status-${type}`
    }
  }
  
  resetButton() {
    this.button.disabled = false
    this.button.textContent = this.element.dataset.buttonIdle || '🤖 AIで肥料情報を取得・保存'
  }
  
  showAdPopup() {
    if (this.adPopup) {
      this.adPopup.classList.add('show')
      // Prevent body scroll when popup is open
      document.body.style.overflow = 'hidden'
    }
  }
  
  hideAdPopup() {
    if (this.adPopup) {
      this.adPopup.classList.remove('show')
      // Restore body scroll
      document.body.style.overflow = ''
    }
  }
}

