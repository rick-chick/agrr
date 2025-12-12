import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="task-blueprint-card-drag"
export default class extends Controller {
  static targets = ["card", "board", "canvas"]

  connect() {
    // 次のフレームで初期化（DOMが完全に構築された後）
    requestAnimationFrame(() => {
      this.initDraggableCards()
    })
  }

  disconnect() {
    this.cleanup()
  }

  initDraggableCards() {
    // 既存のイベントリスナーを削除
    this.cleanup()

    // ドラッグ状態をリセット
    this.dragState = {
      isDragging: false,
      draggedCard: null,
      startX: 0,
      startY: 0,
      offsetX: 0,
      offsetY: 0,
      boardElement: null,
      canvasElement: null,
      totalGdd: 0,
      laneCount: 0
    }

    // カードにイベントリスナーを追加
    this.cardTargets.forEach(card => {
      // 既にイベントリスナーが設定されている場合はスキップ
      if (card.dataset.dragInitialized === 'true') {
        return
      }

      card.addEventListener('mousedown', this.handleMouseDown.bind(this))
      card.addEventListener('touchstart', this.handleTouchStart.bind(this), { passive: false })
      card.dataset.dragInitialized = 'true'
    })
  }

  handleMouseDown(e) {
    if (e.button !== 0) return // 左クリックのみ

    const card = e.currentTarget
    if (!card || !card.classList.contains('draggable-card')) return

    e.preventDefault()
    e.stopPropagation()

    this.startDrag(card, e.clientX, e.clientY)

    // グローバルイベントリスナーを追加
    document.addEventListener('mousemove', this.handleMouseMove)
    document.addEventListener('mouseup', this.handleMouseUp)
  }

  handleTouchStart(e) {
    const card = e.currentTarget
    if (!card || !card.classList.contains('draggable-card')) return

    e.preventDefault()
    e.stopPropagation()

    const touch = e.touches[0]
    this.startDrag(card, touch.clientX, touch.clientY)

    // グローバルイベントリスナーを追加
    document.addEventListener('touchmove', this.handleTouchMove, { passive: false })
    document.addEventListener('touchend', this.handleTouchEnd)
    document.addEventListener('touchcancel', this.handleTouchCancel)
  }

  startDrag(card, clientX, clientY) {
    this.dragState.isDragging = false
    this.dragState.draggedCard = card
    this.dragState.startX = clientX
    this.dragState.startY = clientY

    // ボード要素を取得
    this.dragState.boardElement = this.hasBoardTarget ? this.boardTarget : document.getElementById('task-schedule-blueprints-board')
    this.dragState.canvasElement = this.hasCanvasTarget ? this.canvasTarget : document.getElementById('task-board-canvas')

    if (!this.dragState.boardElement || !this.dragState.canvasElement) {
      console.error('Task schedule blueprints board not found')
      return
    }

    // データ属性を取得
    this.dragState.totalGdd = parseFloat(this.dragState.boardElement.dataset.totalGdd) || 1.0
    this.dragState.laneCount = parseInt(this.dragState.boardElement.dataset.laneCount) || 1

    // カードの現在の中心位置を取得（CSS変数から）
    const canvasRect = this.dragState.canvasElement.getBoundingClientRect()
    const computedStyle = window.getComputedStyle(card)
    const leftPercent = parseFloat(computedStyle.getPropertyValue('--card-left')) || 0
    const topPercent = parseFloat(computedStyle.getPropertyValue('--card-top')) || 0

    // パーセンテージからピクセル位置に変換（カードの中心位置）
    const cardCenterX = canvasRect.left + (leftPercent / 100) * canvasRect.width
    const cardCenterY = canvasRect.top + (topPercent / 100) * canvasRect.height

    // クリック位置からカードの中心位置までのオフセットを計算
    this.dragState.offsetX = clientX - cardCenterX
    this.dragState.offsetY = clientY - cardCenterY

    // カードにdraggingクラスを追加
    card.classList.add('card-dragging')
  }

  handleMouseMove = (e) => {
    if (!this.dragState.draggedCard) return

    const deltaX = Math.abs(e.clientX - this.dragState.startX)
    const deltaY = Math.abs(e.clientY - this.dragState.startY)

    // ドラッグ閾値（5px）を超えたらドラッグ開始
    if (!this.dragState.isDragging && (deltaX > 5 || deltaY > 5)) {
      this.dragState.isDragging = true
    }

    if (this.dragState.isDragging) {
      this.updateCardPosition(e.clientX, e.clientY)
    }
  }

  handleTouchMove = (e) => {
    if (!this.dragState.draggedCard) return

    e.preventDefault()
    const touch = e.touches[0]

    const deltaX = Math.abs(touch.clientX - this.dragState.startX)
    const deltaY = Math.abs(touch.clientY - this.dragState.startY)

    // ドラッグ閾値（5px）を超えたらドラッグ開始
    if (!this.dragState.isDragging && (deltaX > 5 || deltaY > 5)) {
      this.dragState.isDragging = true
    }

    if (this.dragState.isDragging) {
      this.updateCardPosition(touch.clientX, touch.clientY)
    }
  }

  updateCardPosition(clientX, clientY) {
    if (!this.dragState.draggedCard || !this.dragState.canvasElement) return

    const canvasRect = this.dragState.canvasElement.getBoundingClientRect()
    const card = this.dragState.draggedCard
    const cardWidth = card.offsetWidth
    const cardHeight = card.offsetHeight

    // マウス位置からカードの中心位置を計算（オフセットを考慮）
    const cardCenterX = clientX - this.dragState.offsetX
    const cardCenterY = clientY - this.dragState.offsetY

    // カードの中心をキャンバス内の相対位置に変換
    let centerX = cardCenterX - canvasRect.left
    let centerY = cardCenterY - canvasRect.top

    // キャンバス内に制限（カードの半分のサイズを考慮）
    const halfWidth = cardWidth / 2
    const halfHeight = cardHeight / 2

    centerX = Math.max(halfWidth, Math.min(centerX, canvasRect.width - halfWidth))
    centerY = Math.max(halfHeight, Math.min(centerY, canvasRect.height - halfHeight))

    // カードの位置を更新（CSS変数を使用）
    const leftPercent = (centerX / canvasRect.width) * 100
    const topPercent = (centerY / canvasRect.height) * 100

    card.style.setProperty('--card-left', `${leftPercent}%`)
    card.style.setProperty('--card-top', `${topPercent}%`)
    card.style.transform = 'translate(-50%, -50%)'
  }

  handleMouseUp = (e) => {
    if (this.dragState.isDragging && this.dragState.draggedCard) {
      this.finalizeDrag()
    }
    this.cleanup()
  }

  handleTouchEnd = (e) => {
    if (this.dragState.isDragging && this.dragState.draggedCard) {
      this.finalizeDrag()
    }
    this.cleanup()
  }

  handleTouchCancel = () => {
    this.cleanup()
  }

  finalizeDrag() {
    const card = this.dragState.draggedCard
    const canvasRect = this.dragState.canvasElement.getBoundingClientRect()
    const cardRect = card.getBoundingClientRect()

    // カードの中心位置を取得
    const cardCenterX = cardRect.left + cardRect.width / 2 - canvasRect.left
    const cardCenterY = cardRect.top + cardRect.height / 2 - canvasRect.top

    // パーセンテージに変換
    const leftPercent = (cardCenterX / canvasRect.width) * 100
    const topPercent = (cardCenterY / canvasRect.height) * 100

    // gdd_triggerを計算（水平方向）
    const gddTrigger = (leftPercent / 100) * this.dragState.totalGdd

    // priorityを計算（縦方向）
    const topRatio = topPercent / 100
    const targetPriority = Math.round(topRatio * this.dragState.laneCount + 0.5)
    const priority = Math.max(1, Math.min(this.dragState.laneCount, targetPriority))

    // APIに送信
    this.updateCardPositionAPI(card, gddTrigger, priority)
  }

  async updateCardPositionAPI(card, gddTrigger, priority) {
    const updateUrl = card.dataset.updateUrl
    if (!updateUrl) {
      console.error('Update URL not found')
      return
    }

    // データ属性を更新
    card.dataset.gddTrigger = gddTrigger.toFixed(1)
    card.dataset.priority = priority.toString()

    // ツールチップのテキストを更新
    this.updateGddTooltip(card, gddTrigger)

    // CSRFトークンを取得
    const csrfToken = document.querySelector('meta[name="csrf-token"]')?.content
    if (!csrfToken) {
      console.error('CSRF token not found')
      return
    }

    try {
      const response = await fetch(updateUrl, {
        method: 'PATCH',
        headers: {
          'Content-Type': 'application/json',
          'X-CSRF-Token': csrfToken,
          'Accept': 'application/json'
        },
        body: JSON.stringify({
          gdd_trigger: gddTrigger,
          priority: priority
        })
      })

      if (!response.ok) {
        throw new Error(`HTTP error! status: ${response.status}`)
      }

      const data = await response.json()

      // サーバーから返された値で更新
      if (data.gdd_trigger !== undefined) {
        card.dataset.gddTrigger = data.gdd_trigger.toFixed(1)
        this.updateGddTooltip(card, data.gdd_trigger)
      }
      if (data.priority !== undefined) {
        card.dataset.priority = data.priority.toString()
      }

      // カードの位置を再計算して更新
      this.updateCardVisualPosition(card, data.gdd_trigger || gddTrigger, data.priority || priority)

      // 他のカードも再配置（priorityが変更された場合）
      if (data.priority !== undefined) {
        this.reorderAllCards()
      }

    } catch (error) {
      console.error('Failed to update card position:', error)
      // エラー時は元の位置に戻す
      this.restoreOriginalPosition(card)
    }
  }

  updateCardVisualPosition(card, gddTrigger, priority) {
    const boardElement = this.dragState.boardElement || document.getElementById('task-schedule-blueprints-board')
    if (!boardElement) return

    const totalGdd = parseFloat(boardElement.dataset.totalGdd) || 1.0
    const laneCount = parseInt(boardElement.dataset.laneCount) || 1

    // 水平位置を計算
    const gddRatio = Math.max(0.0, Math.min(1.0, gddTrigger / totalGdd))
    const leftPercent = Math.max(8.0, Math.min(95.0, gddRatio * 100))

    // 縦位置を計算
    const lanePosition = ((priority - 0.5) / laneCount) * 100
    const topPercent = lanePosition

    card.style.setProperty('--card-left', `${leftPercent}%`)
    card.style.setProperty('--card-top', `${topPercent}%`)
  }

  reorderAllCards() {
    const boardElement = this.dragState.boardElement || document.getElementById('task-schedule-blueprints-board')
    if (!boardElement) return

    const cards = Array.from(document.querySelectorAll('.draggable-card'))
    const totalGdd = parseFloat(boardElement.dataset.totalGdd) || 1.0
    const laneCount = parseInt(boardElement.dataset.laneCount) || 1

    // gdd_triggerとpriorityでソート
    cards.sort((a, b) => {
      const gddA = parseFloat(a.dataset.gddTrigger) || 0
      const gddB = parseFloat(b.dataset.gddTrigger) || 0
      const priorityA = parseInt(a.dataset.priority) || 0
      const priorityB = parseInt(b.dataset.priority) || 0

      if (gddA !== gddB) {
        return gddA - gddB
      }
      return priorityA - priorityB
    })

    // 各カードの位置を更新
    cards.forEach((card, index) => {
      const gddTrigger = parseFloat(card.dataset.gddTrigger) || 0
      this.updateCardVisualPosition(card, gddTrigger, index + 1)
    })
  }

  updateGddTooltip(card, gddTrigger) {
    const currentTooltip = card.getAttribute('data-gdd-tooltip') || ''
    let label = 'GDDトリガー'

    const match = currentTooltip.match(/^([^:]+):/)
    if (match) {
      label = match[1].trim()
    } else {
      if (typeof getI18nMessage === 'function') {
        label = getI18nMessage('crops.show.gdd_trigger', 'GDDトリガー')
      }
    }

    const tooltipText = `${label}: ${gddTrigger.toFixed(1)}`
    card.setAttribute('data-gdd-tooltip', tooltipText)
  }

  restoreOriginalPosition(card) {
    const gddTrigger = parseFloat(card.dataset.gddTrigger) || 0
    const priority = parseInt(card.dataset.priority) || 1
    this.updateCardVisualPosition(card, gddTrigger, priority)
  }

  cleanup() {
    if (this.dragState?.draggedCard) {
      this.dragState.draggedCard.classList.remove('card-dragging')
    }

    document.removeEventListener('mousemove', this.handleMouseMove)
    document.removeEventListener('mouseup', this.handleMouseUp)
    document.removeEventListener('touchmove', this.handleTouchMove)
    document.removeEventListener('touchend', this.handleTouchEnd)
    document.removeEventListener('touchcancel', this.handleTouchCancel)

    // カードのイベントリスナーを削除
    this.cardTargets.forEach(card => {
      if (card.dataset.dragInitialized === 'true') {
        card.removeEventListener('mousedown', this.handleMouseDown)
        card.removeEventListener('touchstart', this.handleTouchStart)
        card.dataset.dragInitialized = 'false'
      }
    })

    this.dragState = {
      isDragging: false,
      draggedCard: null,
      startX: 0,
      startY: 0,
      offsetX: 0,
      offsetY: 0,
      boardElement: null,
      canvasElement: null,
      totalGdd: 0,
      laneCount: 0
    }
  }
}

