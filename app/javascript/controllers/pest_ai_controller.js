import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="pest-ai"
export default class extends Controller {
  connect() {
    console.log('[PestAiController] connect() called')
    this.button = this.element
    this.statusDiv = document.getElementById('ai-save-status')
    this.nameField = document.querySelector('input[name="pest[name]"]')
    this.adPopup = document.getElementById('ad-popup-overlay')
    this.isNewRecord = this.element.dataset.isNewRecord === 'true'
    this.pestId = this.element.dataset.pestId
    
    console.log('[PestAiController] button:', this.button)
    console.log('[PestAiController] nameField:', this.nameField)
    console.log('[PestAiController] statusDiv:', this.statusDiv)
    console.log('[PestAiController] adPopup:', this.adPopup)
    console.log('[PestAiController] isNewRecord:', this.isNewRecord)
    console.log('[PestAiController] pestId:', this.pestId)
    
    if (!this.button) {
      console.error('[PestAiController] Button element not found!')
      return
    }
    
    // ボタンのテキストを初期化
    this.button.textContent = this.element.dataset.buttonIdle || '🤖 AIで害虫情報を取得・保存'
    
    this.button.addEventListener('click', this.savePest.bind(this))
    console.log('[PestAiController] Event listener attached')
  }

  async savePest(event) {
    console.log('[PestAiController] savePest() called', event)
    event.preventDefault()
    
    const pestName = this.nameField?.value?.trim()
    console.log('[PestAiController] pestName:', pestName)
    
    // Validation
    if (!pestName) {
      console.log('[PestAiController] Validation failed: no pest name')
      this.showStatus(this.element.dataset.enterName || '害虫名を入力してください', 'error')
      return
    }
    
    // Get selected crop IDs and names
    const selectedCropCheckboxes = document.querySelectorAll('input[name="crop_ids[]"]:checked')
    console.log('[PestAiController] Found', selectedCropCheckboxes.length, 'checked crop checkboxes')
    
    const affectedCrops = Array.from(selectedCropCheckboxes).map(checkbox => {
      const cropId = checkbox.value
      // data属性から作物名を取得（より確実）
      const cropName = checkbox.dataset.cropName || ''
      console.log('[PestAiController] Crop:', cropId, 'Name:', cropName, 'Dataset:', checkbox.dataset)
      return { crop_id: cropId, crop_name: cropName }
    })
    console.log('[PestAiController] affectedCrops:', JSON.stringify(affectedCrops))
    
    // Disable button and show loading
    this.button.disabled = true
    this.button.textContent = this.element.dataset.buttonFetching || '🤖 AIで情報を取得中...'
    this.showStatus(this.element.dataset.fetching || 'AIで害虫情報を取得しています...', 'info')
    
    // Show advertisement popup
    this.showAdPopup()
    
    try {
      const csrfToken = document.querySelector('[name="csrf-token"]')?.content
      
      let endpoint, method
      if (this.isNewRecord) {
        // 新規作成
        endpoint = '/api/v1/pests/ai_create'
        method = 'POST'
      } else {
        // 更新
        endpoint = `/api/v1/pests/${this.pestId}/ai_update`
        method = 'POST'
      }
      
      const response = await fetch(endpoint, {
        method: method,
        headers: {
          'Content-Type': 'application/json',
          'X-CSRF-Token': csrfToken
        },
        credentials: 'include', // セッションクッキーを含める
        body: JSON.stringify({ 
          name: pestName,
          affected_crops: affectedCrops
        })
      })
      
      const data = await response.json()
      
      if (response.ok) {
        // 成功時：広告を閉じて遷移
        // 新規作成時は詳細画面、編集時は編集画面に遷移（Cropの動作に合わせる）
        // APIレスポンスのmessageを使用（ai_create=作成、ai_update=更新で正しいメッセージを返す）
        const successMsg = data.message || (this.isNewRecord
          ? (this.element.dataset.createdSuccess || '✓ 害虫「%{name}」の情報を取得して保存しました！').replace('%{name}', data.pest_name || '')
          : (this.element.dataset.updatedSuccess || '✓ 害虫「%{name}」の情報を取得して更新しました！').replace('%{name}', data.pest_name || ''))
        
        this.showStatus('✓ ' + successMsg, 'success')
        
        // Wait a moment to show success message, then redirect
        setTimeout(() => {
          this.hideAdPopup()
          const id = data.pest_id
          const redirectTo = id
            ? (this.isNewRecord ? `/pests/${id}` : `/pests/${id}/edit`)
            : '/pests' // フォールバック
          if (window.Turbo && window.Turbo.visit) {
            window.Turbo.visit(redirectTo)
          } else {
            window.location.href = redirectTo
          }
        }, 1500)
      } else {
        this.hideAdPopup()
        this.showStatus(`エラー: ${data.error || (this.element.dataset.fetchFailed || '害虫情報の取得に失敗しました')}` , 'error')
        this.resetButton()
      }
    } catch (error) {
      console.error('Error in AI pest creation:', error)
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
    this.button.textContent = this.element.dataset.buttonIdle || '🤖 AIで害虫情報を取得・保存'
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

