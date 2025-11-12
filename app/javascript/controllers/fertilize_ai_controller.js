import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="fertilize-ai"
export default class extends Controller {
  connect() {
    console.log('[FertilizeAiController] connect() called')
    this.button = this.element
    this.statusDiv = document.getElementById('ai-save-status')
    this.nameField = document.querySelector('input[name="fertilize[name]"]')
    this.adPopup = document.getElementById('ad-popup-overlay')
    this.isNewRecord = this.element.dataset.isNewRecord === 'true'
    this.fertilizeId = this.element.dataset.fertilizeId
    
    console.log('[FertilizeAiController] button:', this.button)
    console.log('[FertilizeAiController] nameField:', this.nameField)
    console.log('[FertilizeAiController] statusDiv:', this.statusDiv)
    console.log('[FertilizeAiController] adPopup:', this.adPopup)
    console.log('[FertilizeAiController] isNewRecord:', this.isNewRecord)
    console.log('[FertilizeAiController] fertilizeId:', this.fertilizeId)
    
    if (!this.button) {
      console.error('[FertilizeAiController] Button element not found!')
      return
    }
    
    // ボタンのテキストを初期化
    this.button.textContent = this.element.dataset.buttonIdle || '🤖 AIで肥料情報を取得・保存'
    
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
    
    // Show advertisement popup
    this.showAdPopup()
    
    const baseMessage = this.element.dataset.fetching || 'AIで肥料情報を取得しています...'
    this.showStatus(baseMessage, 'loading')
    
    try {
      const csrfToken = document.querySelector('[name="csrf-token"]')?.content
      
      let endpoint, method
      if (this.isNewRecord) {
        // 新規作成
        endpoint = '/api/v1/fertilizes/ai_create'
        method = 'POST'
      } else {
        // 更新
        endpoint = `/api/v1/fertilizes/${this.fertilizeId}/ai_update`
        method = 'POST'
      }
      
      const response = await fetch(endpoint, {
        method: method,
        headers: {
          'Content-Type': 'application/json',
          'X-CSRF-Token': csrfToken
        },
        body: JSON.stringify({ 
          name: fertilizeName
        })
      })
      
      const data = await response.json()
      console.log('[FertilizeAiController] response status:', response.status, 'ok:', response.ok, 'data:', data)

      if (response.ok) {
        // 成功時：広告を閉じて遷移
        // 新規作成時は詳細画面、編集時は編集画面に遷移（Cropの動作に合わせる）
        // APIレスポンスのmessageを使用（ai_create=作成、ai_update=更新で正しいメッセージを返す）
        const successMsg = data.message || (this.isNewRecord
          ? (this.element.dataset.createdSuccess || '✓ 肥料「%{name}」の情報を取得して保存しました！').replace('%{name}', data.fertilize_name || '')
          : (this.element.dataset.updatedSuccess || '✓ 肥料「%{name}」の情報を取得して更新しました！').replace('%{name}', data.fertilize_name || ''))
        
        this.showStatus(`${baseMessage} / ${successMsg}`, 'success')
        
        // Wait a moment to show success message, then redirect
        setTimeout(() => {
          this.hideAdPopup()
          if (this.isNewRecord) {
            // 新規作成時：詳細画面に遷移（Cropと同じ動作）
            window.location.href = `/fertilizes/${data.fertilize_id}`
          } else {
            // 編集時：編集画面に戻る
            window.location.href = `/fertilizes/${data.fertilize_id}/edit`
          }
        }, 1500)
      } else {
        this.hideAdPopup()
        const errorMessage = data.error || (this.element.dataset.fetchFailed || '肥料情報の取得に失敗しました')
        this.showStatus(`${baseMessage} / エラー: ${errorMessage}`, 'error')
        this.resetButton()
      }
    } catch (error) {
      console.error('Error in AI fertilize creation:', error)
      this.hideAdPopup()
      const networkMessage = this.element.dataset.networkError || 'ネットワークエラーが発生しました'
      this.showStatus(`${baseMessage} / エラー: ${networkMessage}`, 'error')
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
    window.setTimeout(() => {
      this.button.disabled = false
      this.button.textContent = this.element.dataset.buttonIdle || '🤖 AIで肥料情報を取得・保存'
    }, 300)
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

