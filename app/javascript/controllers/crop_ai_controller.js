import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="crop-ai"
export default class extends Controller {
  connect() {
    this.button = this.element
    this.statusDiv = document.getElementById('ai-save-status')
    this.nameField = document.querySelector('input[name="crop[name]"]')
    this.varietyField = document.querySelector('input[name="crop[variety]"]')
    this.adPopup = document.getElementById('ad-popup-overlay')
    
    this.button.addEventListener('click', this.saveCrop.bind(this))
  }

  async saveCrop(event) {
    event.preventDefault()
    
    const cropName = this.nameField?.value?.trim()
    const variety = this.varietyField?.value?.trim()
    
    // Validation
    if (!cropName) {
      this.showStatus(this.element.dataset.enterName || this.translate('cropAiEnterName', '作物名を入力してください'), 'error')
      return
    }
    
    // Disable button and show loading
    this.button.disabled = true
    this.button.textContent = this.element.dataset.buttonFetching || this.translate('cropAiButtonFetching', '🤖 AIで情報を取得中...')
    this.showStatus(this.element.dataset.fetching || this.translate('cropAiFetching', 'AIで作物情報を取得しています...'), 'info')
    
    // Show advertisement popup
    this.showAdPopup()
    
    try {
      const csrfToken = document.querySelector('[name="csrf-token"]')?.content
      
      // AI Create APIを呼び出し（agrrコマンドで情報取得 + 保存）
      const response = await fetch('/api/v1/crops/ai_create', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'X-CSRF-Token': csrfToken
        },
        body: JSON.stringify({ 
          name: cropName,
          variety: variety || null
        })
      })
      
      const data = await response.json()
      
      if (response.ok) {
        // 成功時：広告を閉じて作物詳細画面に遷移
        const successTemplate = this.element.dataset.createdSuccess || this.translate('cropAiCreatedSuccess', '✓ 作物「%{name}」の情報を取得して保存しました！')
        this.showStatus(successTemplate.replace('%{name}', data.crop_name), 'success')
        
        // Wait a moment to show success message, then redirect
        setTimeout(() => {
          this.hideAdPopup()
          window.location.href = `/crops/${data.crop_id}`
        }, 1500)
      } else {
        this.hideAdPopup()
        const failed = this.element.dataset.fetchFailed || this.translate('cropAiFetchFailed', '作物情報の取得に失敗しました')
        this.showStatus(`エラー: ${data.error || failed}` , 'error')
        this.resetButton()
      }
    } catch (error) {
      console.error('Error in AI crop creation:', error)
      this.hideAdPopup()
      this.showStatus(this.element.dataset.networkError || this.translate('cropAiNetworkError', 'ネットワークエラーが発生しました'), 'error')
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
    this.button.textContent = this.element.dataset.buttonIdle || this.translate('cropAiButtonIdle', '🤖 AIで作物情報を取得・保存')
  }
  
  showAdPopup() {
    if (this.adPopup) {
      this.adPopup.classList.add('show')
      // Prevent body scroll when popup is open
      document.body.style.overflow = 'hidden'
      
      // Initialize ads after popup is shown (to avoid "availableWidth=0" error)
      setTimeout(() => {
        const adElements = this.adPopup.querySelectorAll('.adsbygoogle')
        if (adElements.length > 0 && window.adsbygoogle) {
          try {
            adElements.forEach((element) => {
              if (!element.dataset.adInitialized) {
                window.adsbygoogle.push({})
                element.dataset.adInitialized = 'true'
              }
            })
          } catch (error) {
            console.warn('Ad initialization error (non-critical):', error)
          }
        }
      }, 100)
    }
  }
  
  hideAdPopup() {
    if (this.adPopup) {
      this.adPopup.classList.remove('show')
      // Restore body scroll
      document.body.style.overflow = ''
    }
  }

  translate(key, fallback) {
    if (typeof getI18nMessage === 'function') {
      return getI18nMessage(key, fallback)
    }
    return fallback
  }
}


