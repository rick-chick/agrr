// app/assets/javascripts/svg_drag_utils.js
// SVGドラッグ&ドロップ共通ユーティリティ

/**
 * SVGドラッグマネージャー
 * SVG要素のドラッグ&ドロップを管理する再利用可能なクラス
 */
class SVGDragManager {
  constructor(svgElement, options = {}) {
    this.svg = svgElement;
    this.options = {
      dragThreshold: options.dragThreshold || 5,
      draggingClass: options.draggingClass || 'dragging',
      onDragStart: options.onDragStart || null,
      onDrag: options.onDrag || null,
      onDragEnd: options.onDragEnd || null,
      ...options
    };
    
    // ドラッグ状態
    this.state = {
      isDragging: false,
      draggedElement: null,
      startX: 0,
      startY: 0,
      originalX: 0,
      originalY: 0,
      offset: { x: 0, y: 0 }
    };
    
    // グローバルハンドラー
    this.mouseMoveHandler = null;
    this.mouseUpHandler = null;
  }
  
  /**
   * スクリーン座標をSVG座標に変換
   */
  screenToSVGCoords(screenX, screenY) {
    if (!this.svg) {
      console.warn('SVG element is null, returning screen coordinates');
      return { x: screenX, y: screenY };
    }
    
    const pt = this.svg.createSVGPoint();
    pt.x = screenX;
    pt.y = screenY;
    const ctm = this.svg.getScreenCTM();
    
    if (ctm) {
      return pt.matrixTransform(ctm.inverse());
    }
    
    return { x: screenX, y: screenY };
  }
  
  /**
   * 要素にドラッグ可能機能を追加
   */
  makeDraggable(element, config = {}) {
    const {
      getPosition = (el) => ({
        x: parseFloat(el.getAttribute('x')) || 0,
        y: parseFloat(el.getAttribute('y')) || 0
      }),
      setPosition = (el, x, y) => {
        el.setAttribute('x', x);
        el.setAttribute('y', y);
      },
      onMouseDown = null,
      onMouseMove = null,
      onMouseUp = null
    } = config;
    
    element.addEventListener('mousedown', (e) => {
      if (e.button !== 0) return; // 左クリックのみ
      
      this.state.draggedElement = element;
      this.state.startX = e.clientX;
      this.state.startY = e.clientY;
      
      const currentPos = getPosition(element);
      this.state.originalX = currentPos.x;
      this.state.originalY = currentPos.y;
      
      // SVG座標系でのオフセットを計算
      const startSvgCoords = this.screenToSVGCoords(e.clientX, e.clientY);
      this.state.offset.x = startSvgCoords.x - currentPos.x;
      this.state.offset.y = startSvgCoords.y - currentPos.y;
      
      if (onMouseDown) {
        onMouseDown(e, this.state);
      }
      
      e.preventDefault();
    });
    
    // グローバルマウスムーブハンドラー（ドラッグ閾値判定含む）
    if (!this.mouseMoveHandler) {
      this.mouseMoveHandler = (e) => {
        if (!this.state.draggedElement) return;
        
        const deltaX = e.clientX - this.state.startX;
        const deltaY = e.clientY - this.state.startY;
        
        // ドラッグ開始判定
        if (!this.state.isDragging) {
          const distance = Math.sqrt(deltaX * deltaX + deltaY * deltaY);
          if (distance > this.options.dragThreshold) {
            this.state.isDragging = true;
            
            // draggingクラスを追加（CSS transition無効化用）
            if (this.options.draggingClass) {
              this.state.draggedElement.classList.add(this.options.draggingClass);
            }
            
            if (this.options.onDragStart) {
              this.options.onDragStart(this.state.draggedElement, this.state);
            }
          } else {
            return;
          }
        }
        
        // 現在のマウス位置をSVG座標に変換
        const currentSvgCoords = this.screenToSVGCoords(e.clientX, e.clientY);
        
        // マウスの下に要素の基準点が来るように位置を計算
        const newX = currentSvgCoords.x - this.state.offset.x;
        const newY = currentSvgCoords.y - this.state.offset.y;
        
        // 位置を更新
        setPosition(this.state.draggedElement, newX, newY);
        
        if (onMouseMove) {
          onMouseMove(e, { newX, newY, ...this.state });
        }
        
        if (this.options.onDrag) {
          this.options.onDrag(this.state.draggedElement, { newX, newY, ...this.state });
        }
      };
      
      document.addEventListener('mousemove', this.mouseMoveHandler);
    }
    
    // グローバルマウスアップハンドラー
    if (!this.mouseUpHandler) {
      this.mouseUpHandler = (e) => {
        if (!this.state.draggedElement) return;
        
        const element = this.state.draggedElement;
        const wasDragging = this.state.isDragging;
        
        // draggingクラスを削除
        if (this.options.draggingClass) {
          element.classList.remove(this.options.draggingClass);
        }
        
        if (wasDragging) {
          const currentPos = getPosition(element);
          
          if (onMouseUp) {
            onMouseUp(e, { ...currentPos, ...this.state });
          }
          
          if (this.options.onDragEnd) {
            this.options.onDragEnd(element, { ...currentPos, ...this.state });
          }
        }
        
        // 状態をリセット
        this.state.draggedElement = null;
        this.state.isDragging = false;
      };
      
      document.addEventListener('mouseup', this.mouseUpHandler);
    }
  }
  
  /**
   * ドラッグ機能をクリーンアップ
   */
  destroy() {
    if (this.mouseMoveHandler) {
      document.removeEventListener('mousemove', this.mouseMoveHandler);
      this.mouseMoveHandler = null;
    }
    
    if (this.mouseUpHandler) {
      document.removeEventListener('mouseup', this.mouseUpHandler);
      this.mouseUpHandler = null;
    }
  }
  
  /**
   * 現在のドラッグ状態を取得
   */
  getState() {
    return { ...this.state };
  }
  
  /**
   * ドラッグ中かどうか
   */
  isDragging() {
    return this.state.isDragging;
  }
}

/**
 * SVGハイライトマネージャー
 * ドラッグ時のハイライト表示を管理
 */
class SVGHighlightManager {
  constructor(svg, options = {}) {
    this.svg = svg;
    this.options = {
      fill: options.fill || '#FFEB3B',
      opacity: options.opacity || 0.4,
      className: options.className || 'highlight-zone',
      ...options
    };
    
    this.highlightRect = null;
    this.createHighlight();
  }
  
  /**
   * ハイライト要素を作成
   */
  createHighlight() {
    if (!this.svg) return;
    
    this.highlightRect = document.createElementNS('http://www.w3.org/2000/svg', 'rect');
    this.highlightRect.setAttribute('class', this.options.className);
    this.highlightRect.setAttribute('fill', this.options.fill);
    this.highlightRect.setAttribute('opacity', '0');
    this.highlightRect.setAttribute('pointer-events', 'none');
    
    // SVGの最初の子要素として挿入（背景として）
    this.svg.insertBefore(this.highlightRect, this.svg.firstChild);
  }
  
  /**
   * ハイライトを表示
   */
  show(x, y, width, height) {
    if (!this.highlightRect) return;
    
    this.highlightRect.setAttribute('x', x);
    this.highlightRect.setAttribute('y', y);
    this.highlightRect.setAttribute('width', width);
    this.highlightRect.setAttribute('height', height);
    this.highlightRect.setAttribute('opacity', this.options.opacity);
  }
  
  /**
   * ハイライトを非表示
   */
  hide() {
    if (!this.highlightRect) return;
    this.highlightRect.setAttribute('opacity', '0');
  }
  
  /**
   * ハイライトを削除
   */
  destroy() {
    if (this.highlightRect) {
      this.highlightRect.remove();
      this.highlightRect = null;
    }
  }
}

/**
 * 要素キャッシュマネージャー
 * DOM検索の最適化用
 */
class ElementCache {
  constructor() {
    this.cache = new Map();
  }
  
  /**
   * 要素をキャッシュに追加
   */
  set(key, selector, parent = document) {
    if (!this.cache.has(key)) {
      const element = parent.querySelector(selector);
      if (element) {
        this.cache.set(key, element);
      }
    }
    return this.cache.get(key);
  }
  
  /**
   * 複数の要素をキャッシュ
   */
  setMultiple(elements, parent = document) {
    Object.entries(elements).forEach(([key, selector]) => {
      this.set(key, selector, parent);
    });
  }
  
  /**
   * キャッシュから要素を取得
   */
  get(key) {
    return this.cache.get(key);
  }
  
  /**
   * キャッシュをクリア
   */
  clear() {
    this.cache.clear();
  }
  
  /**
   * 特定のキーを削除
   */
  delete(key) {
    this.cache.delete(key);
  }
}

// グローバルに公開
window.SVGDragManager = SVGDragManager;
window.SVGHighlightManager = SVGHighlightManager;
window.ElementCache = ElementCache;

// エクスポート（モジュールシステム用）
if (typeof module !== 'undefined' && module.exports) {
  module.exports = {
    SVGDragManager,
    SVGHighlightManager,
    ElementCache
  };
}

