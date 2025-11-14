// app/assets/javascripts/task_blueprint_card_drag.js
// 作業予定カードのドラッグアンドドロップ機能

(function() {
  'use strict';

  // ドラッグ状態管理
  let dragState = {
    isDragging: false,
    draggedCard: null,
    startX: 0,
    startY: 0,
    originalLeft: 0,
    originalTop: 0,
    offsetX: 0,
    offsetY: 0,
    boardElement: null,
    canvasElement: null,
    totalGdd: 0,
    laneCount: 0
  };

  /**
   * カードを初期化してドラッグ可能にする
   */
  function initDraggableCards() {
    const cards = document.querySelectorAll('.draggable-card');
    
    cards.forEach(card => {
      // マウスダウンイベント
      card.addEventListener('mousedown', handleMouseDown);
      
      // タッチイベント（モバイル対応）
      card.addEventListener('touchstart', handleTouchStart, { passive: false });
    });
  }

  /**
   * マウスダウンイベントハンドラー
   */
  function handleMouseDown(e) {
    if (e.button !== 0) return; // 左クリックのみ
    
    const card = e.currentTarget;
    if (!card || !card.classList.contains('draggable-card')) return;

    e.preventDefault();
    e.stopPropagation();

    startDrag(card, e.clientX, e.clientY);
    
    // グローバルイベントリスナーを追加
    document.addEventListener('mousemove', handleMouseMove);
    document.addEventListener('mouseup', handleMouseUp);
  }

  /**
   * タッチスタートイベントハンドラー
   */
  function handleTouchStart(e) {
    const card = e.currentTarget;
    if (!card || !card.classList.contains('draggable-card')) return;

    e.preventDefault();
    e.stopPropagation();

    const touch = e.touches[0];
    startDrag(card, touch.clientX, touch.clientY);
    
    // グローバルイベントリスナーを追加
    document.addEventListener('touchmove', handleTouchMove, { passive: false });
    document.addEventListener('touchend', handleTouchEnd);
  }

  /**
   * ドラッグを開始
   */
  function startDrag(card, clientX, clientY) {
    dragState.isDragging = false;
    dragState.draggedCard = card;
    dragState.startX = clientX;
    dragState.startY = clientY;

    // ボード要素を取得
    dragState.boardElement = document.getElementById('task-schedule-blueprints-board');
    dragState.canvasElement = document.getElementById('task-board-canvas');
    
    if (!dragState.boardElement || !dragState.canvasElement) {
      console.error('Task schedule blueprints board not found');
      return;
    }

    // データ属性を取得
    dragState.totalGdd = parseFloat(dragState.boardElement.dataset.totalGdd) || 1.0;
    dragState.laneCount = parseInt(dragState.boardElement.dataset.laneCount) || 1;

    // カードの現在の中心位置を取得（CSS変数から）
    const canvasRect = dragState.canvasElement.getBoundingClientRect();
    const computedStyle = window.getComputedStyle(card);
    const leftPercent = parseFloat(computedStyle.getPropertyValue('--card-left')) || 0;
    const topPercent = parseFloat(computedStyle.getPropertyValue('--card-top')) || 0;
    
    // パーセンテージからピクセル位置に変換（カードの中心位置）
    const cardCenterX = canvasRect.left + (leftPercent / 100) * canvasRect.width;
    const cardCenterY = canvasRect.top + (topPercent / 100) * canvasRect.height;
    
    // クリック位置からカードの中心位置までのオフセットを計算
    dragState.offsetX = clientX - cardCenterX;
    dragState.offsetY = clientY - cardCenterY;

    // カードにdraggingクラスを追加
    card.classList.add('card-dragging');
  }

  /**
   * マウスムーブイベントハンドラー
   */
  function handleMouseMove(e) {
    if (!dragState.draggedCard) return;

    const deltaX = Math.abs(e.clientX - dragState.startX);
    const deltaY = Math.abs(e.clientY - dragState.startY);

    // ドラッグ閾値（5px）を超えたらドラッグ開始
    if (!dragState.isDragging && (deltaX > 5 || deltaY > 5)) {
      dragState.isDragging = true;
    }

    if (dragState.isDragging) {
      updateCardPosition(e.clientX, e.clientY);
    }
  }

  /**
   * タッチムーブイベントハンドラー
   */
  function handleTouchMove(e) {
    if (!dragState.draggedCard) return;

    e.preventDefault();
    const touch = e.touches[0];
    
    const deltaX = Math.abs(touch.clientX - dragState.startX);
    const deltaY = Math.abs(touch.clientY - dragState.startY);

    // ドラッグ閾値（5px）を超えたらドラッグ開始
    if (!dragState.isDragging && (deltaX > 5 || deltaY > 5)) {
      dragState.isDragging = true;
    }

    if (dragState.isDragging) {
      updateCardPosition(touch.clientX, touch.clientY);
    }
  }

  /**
   * カードの位置を更新
   */
  function updateCardPosition(clientX, clientY) {
    if (!dragState.draggedCard || !dragState.canvasElement) return;
    
    const canvasRect = dragState.canvasElement.getBoundingClientRect();
    const card = dragState.draggedCard;
    const cardWidth = card.offsetWidth;
    const cardHeight = card.offsetHeight;
    
    // マウス位置からカードの中心位置を計算（オフセットを考慮）
    // カードは translate(-50%, -50%) で中心揃えされているため、中心位置を基準にする
    const cardCenterX = clientX - dragState.offsetX;
    const cardCenterY = clientY - dragState.offsetY;
    
    // カードの中心をキャンバス内の相対位置に変換（スクリーン座標からキャンバス座標へ）
    let centerX = cardCenterX - canvasRect.left;
    let centerY = cardCenterY - canvasRect.top;

    // キャンバス内に制限（カードの半分のサイズを考慮）
    const halfWidth = cardWidth / 2;
    const halfHeight = cardHeight / 2;
    
    centerX = Math.max(halfWidth, Math.min(centerX, canvasRect.width - halfWidth));
    centerY = Math.max(halfHeight, Math.min(centerY, canvasRect.height - halfHeight));

    // カードの位置を更新（CSS変数を使用、パーセンテージは中心位置）
    const leftPercent = (centerX / canvasRect.width) * 100;
    const topPercent = (centerY / canvasRect.height) * 100;
    
    // CSS変数を更新してカードの位置を変更
    card.style.setProperty('--card-left', `${leftPercent}%`);
    card.style.setProperty('--card-top', `${topPercent}%`);
    // transformは既にCSSで設定されているので、明示的に設定する必要はないが念のため
    card.style.transform = 'translate(-50%, -50%)';
  }

  /**
   * マウスアップイベントハンドラー
   */
  function handleMouseUp(e) {
    if (dragState.isDragging && dragState.draggedCard) {
      finalizeDrag();
    }
    cleanup();
  }

  /**
   * タッチエンドイベントハンドラー
   */
  function handleTouchEnd(e) {
    if (dragState.isDragging && dragState.draggedCard) {
      finalizeDrag();
    }
    cleanup();
  }

  /**
   * ドラッグを確定してAPIに送信
   */
  function finalizeDrag() {
    const card = dragState.draggedCard;
    const canvasRect = dragState.canvasElement.getBoundingClientRect();
    const cardRect = card.getBoundingClientRect();
    
    // カードの中心位置を取得
    const cardCenterX = cardRect.left + cardRect.width / 2 - canvasRect.left;
    const cardCenterY = cardRect.top + cardRect.height / 2 - canvasRect.top;
    
    // パーセンテージに変換
    const leftPercent = (cardCenterX / canvasRect.width) * 100;
    const topPercent = (cardCenterY / canvasRect.height) * 100;
    
    // gdd_triggerを計算（水平方向）
    const gddTrigger = (leftPercent / 100) * dragState.totalGdd;
    
    // priorityを計算（縦方向）- レーン位置を計算
    // レーンの中心位置は ((priority - 0.5) / laneCount) * 100% で計算される
    // 逆に、カードの中心位置からpriorityを計算する
    // topPercentは0-100の範囲
    const topRatio = topPercent / 100; // 0-1の範囲に変換
    const targetPriority = Math.round(topRatio * dragState.laneCount + 0.5);
    const priority = Math.max(1, Math.min(dragState.laneCount, targetPriority));
    
    // APIに送信
    updateCardPositionAPI(card, gddTrigger, priority);
  }

  /**
   * APIに位置更新を送信
   */
  async function updateCardPositionAPI(card, gddTrigger, priority) {
    const updateUrl = card.dataset.updateUrl;
    if (!updateUrl) {
      console.error('Update URL not found');
      return;
    }

    // データ属性を更新
    card.dataset.gddTrigger = gddTrigger.toFixed(1);
    card.dataset.priority = priority.toString();
    
    // ツールチップのテキストを更新
    updateGddTooltip(card, gddTrigger);

    // CSRFトークンを取得
    const csrfToken = document.querySelector('meta[name="csrf-token"]')?.content;
    if (!csrfToken) {
      console.error('CSRF token not found');
      return;
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
      });

      if (!response.ok) {
        throw new Error(`HTTP error! status: ${response.status}`);
      }

      const data = await response.json();
      
      // サーバーから返された値で更新
      if (data.gdd_trigger !== undefined) {
        card.dataset.gddTrigger = data.gdd_trigger.toFixed(1);
        // ツールチップも更新
        updateGddTooltip(card, data.gdd_trigger);
      }
      if (data.priority !== undefined) {
        card.dataset.priority = data.priority.toString();
      }

      // カードの位置を再計算して更新
      updateCardVisualPosition(card, data.gdd_trigger || gddTrigger, data.priority || priority);
      
      // 他のカードも再配置（priorityが変更された場合）
      if (data.priority !== undefined) {
        reorderAllCards();
      }

    } catch (error) {
      console.error('Failed to update card position:', error);
      // エラー時は元の位置に戻す
      restoreOriginalPosition(card);
    }
  }

  /**
   * カードの視覚的位置を更新
   */
  function updateCardVisualPosition(card, gddTrigger, priority) {
    const boardElement = document.getElementById('task-schedule-blueprints-board');
    if (!boardElement) return;

    const totalGdd = parseFloat(boardElement.dataset.totalGdd) || 1.0;
    const laneCount = parseInt(boardElement.dataset.laneCount) || 1;
    
    // 水平位置を計算
    const gddRatio = Math.max(0.0, Math.min(1.0, gddTrigger / totalGdd));
    const leftPercent = Math.max(8.0, Math.min(95.0, gddRatio * 100));
    
    // 縦位置を計算
    const lanePosition = ((priority - 0.5) / laneCount) * 100;
    const topPercent = lanePosition;
    
    card.style.setProperty('--card-left', `${leftPercent}%`);
    card.style.setProperty('--card-top', `${topPercent}%`);
  }

  /**
   * すべてのカードを再配置
   */
  function reorderAllCards() {
    const boardElement = document.getElementById('task-schedule-blueprints-board');
    if (!boardElement) return;

    const cards = Array.from(document.querySelectorAll('.draggable-card'));
    const totalGdd = parseFloat(boardElement.dataset.totalGdd) || 1.0;
    const laneCount = parseInt(boardElement.dataset.laneCount) || 1;

    // gdd_triggerとpriorityでソート
    cards.sort((a, b) => {
      const gddA = parseFloat(a.dataset.gddTrigger) || 0;
      const gddB = parseFloat(b.dataset.gddTrigger) || 0;
      const priorityA = parseInt(a.dataset.priority) || 0;
      const priorityB = parseInt(b.dataset.priority) || 0;
      
      if (gddA !== gddB) {
        return gddA - gddB;
      }
      return priorityA - priorityB;
    });

    // 各カードの位置を更新
    cards.forEach((card, index) => {
      const gddTrigger = parseFloat(card.dataset.gddTrigger) || 0;
      updateCardVisualPosition(card, gddTrigger, index + 1);
    });
  }

  /**
   * GDDツールチップのテキストを更新
   */
  function updateGddTooltip(card, gddTrigger) {
    // 既存のツールチップからラベル部分を抽出
    const currentTooltip = card.getAttribute('data-gdd-tooltip') || '';
    let label = 'GDDトリガー'; // デフォルト
    
    // 既存のツールチップからラベルを抽出（例: "GDDトリガー: 100.0" → "GDDトリガー"）
    const match = currentTooltip.match(/^([^:]+):/);
    if (match) {
      label = match[1].trim();
    } else {
      // 既存のツールチップがない場合、グローバル関数を試す
      if (typeof getI18nMessage === 'function') {
        label = getI18nMessage('crops.show.gdd_trigger', 'GDDトリガー');
      }
    }
    
    const tooltipText = `${label}: ${gddTrigger.toFixed(1)}`;
    card.setAttribute('data-gdd-tooltip', tooltipText);
  }

  /**
   * 元の位置に戻す
   */
  function restoreOriginalPosition(card) {
    const gddTrigger = parseFloat(card.dataset.gddTrigger) || 0;
    const priority = parseInt(card.dataset.priority) || 1;
    updateCardVisualPosition(card, gddTrigger, priority);
  }

  /**
   * クリーンアップ
   */
  function cleanup() {
    if (dragState.draggedCard) {
      dragState.draggedCard.classList.remove('card-dragging');
    }

    document.removeEventListener('mousemove', handleMouseMove);
    document.removeEventListener('mouseup', handleMouseUp);
    document.removeEventListener('touchmove', handleTouchMove);
    document.removeEventListener('touchend', handleTouchEnd);

    dragState = {
      isDragging: false,
      draggedCard: null,
      startX: 0,
      startY: 0,
      originalLeft: 0,
      originalTop: 0,
      offsetX: 0,
      offsetY: 0,
      boardElement: null,
      canvasElement: null,
      totalGdd: 0,
      laneCount: 0
    };
  }

  // DOMContentLoaded時に初期化
  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', initDraggableCards);
  } else {
    initDraggableCards();
  }

  // Turboイベントにも対応
  document.addEventListener('turbo:load', initDraggableCards);
  document.addEventListener('turbo:frame-load', initDraggableCards);

})();

