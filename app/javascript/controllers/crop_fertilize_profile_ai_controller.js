import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="crop-fertilize-profile-ai"
export default class extends Controller {
  connect() {
    this.button = this.element
    this.statusDiv = document.getElementById('ai-save-status')
    this.adPopup = document.getElementById('ad-popup-overlay')
    this.isNewRecord = this.element.dataset.isNewRecord === 'true'
    this.cropId = this.element.dataset.cropId
    this.profileId = this.element.dataset.profileId
    
    if (!this.button) {
      console.error('[CropFertilizeProfileAiController] Button element not found!')
      return
    }
    
    // ボタンのテキストを初期化
    this.button.textContent = this.element.dataset.buttonIdle || '🤖 AIで肥料情報を取得・保存'
    
    this.button.addEventListener('click', this.saveProfile.bind(this))
  }

  async saveProfile(event) {
    event.preventDefault()
    
    // Validation
    if (!this.cropId) {
      this.showStatus(this.element.dataset.enterCropName || '作物を選択してください', 'error')
      return
    }
    
    // Disable button and show loading
    this.button.disabled = true
    this.button.textContent = this.element.dataset.buttonFetching || '🤖 AIで情報を取得中...'
    this.showStatus(this.element.dataset.fetching || 'AIで肥料プロファイル情報を取得しています...', 'info')
    
    // Show advertisement popup
    this.showAdPopup()
    
    try {
      const csrfToken = document.querySelector('[name="csrf-token"]')?.content
      
      let endpoint, method
      if (this.isNewRecord) {
        // 新規作成
        endpoint = `/api/v1/crops/${this.cropId}/crop_fertilize_profiles/ai_create`
        method = 'POST'
      } else {
        // 更新
        endpoint = `/api/v1/crops/${this.cropId}/crop_fertilize_profiles/${this.profileId}/ai_update`
        method = 'POST'
      }
      
      const response = await fetch(endpoint, {
        method: method,
        headers: {
          'Content-Type': 'application/json',
          'X-CSRF-Token': csrfToken
        },
        body: JSON.stringify({})
      })
      
      const data = await response.json()
      
      if (response.ok) {
        // 成功時：広告を閉じて遷移
        // 新規作成時は詳細画面、編集時は編集画面に遷移（Cropの動作に合わせる）
        // APIレスポンスのmessageを使用（ai_create=作成、ai_update=更新で正しいメッセージを返す）
        const successMsg = data.message || '処理が完了しました'
        
        this.showStatus('✓ ' + successMsg, 'success')
        
        // Wait a moment to show success message, then redirect
        setTimeout(() => {
          this.hideAdPopup()
          if (this.isNewRecord) {
            // 新規作成時：詳細画面に遷移（Cropと同じ動作）
            window.location.href = `/crops/${this.cropId}/crop_fertilize_profiles/${data.profile_id}`
          } else {
            // 編集時：編集画面に戻る
            window.location.href = `/crops/${this.cropId}/crop_fertilize_profiles/${data.profile_id}/edit`
          }
        }, 1500)
      } else {
        this.hideAdPopup()
        this.showStatus(`エラー: ${data.error || (this.element.dataset.fetchFailed || '肥料プロファイル情報の取得に失敗しました')}`, 'error')
        this.resetButton()
      }
    } catch (error) {
      console.error('Error in AI crop fertilize profile save:', error)
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

  showAdPopup() {
    if (this.adPopup) {
      this.adPopup.classList.add('show')
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
      document.body.style.overflow = ''
    }
  }

  resetButton() {
    if (this.button) {
      this.button.disabled = false
      this.button.textContent = this.element.dataset.buttonIdle || '🤖 AIで肥料情報を取得・保存'
    }
  }
}

