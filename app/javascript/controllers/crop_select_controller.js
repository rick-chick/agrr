import { Controller } from "@hotwired/stimulus";

// Connects to data-controller="crop-select"
export default class extends Controller {
  static targets = ["counter", "submit", "hint"];

  connect() {
    console.log('[CropSelectController] connect() called');
    console.log('[CropSelectController] element:', this.element);
    console.log('[CropSelectController] hasCounterTarget:', this.hasCounterTarget);
    console.log('[CropSelectController] hasSubmitTarget:', this.hasSubmitTarget);
    console.log('[CropSelectController] hasHintTarget:', this.hasHintTarget);
    
    // 初期状態を更新
    this.updateState();
  }

  checkboxElements() {
    return this.element.querySelectorAll('input[type="checkbox"].crop-check');
  }

  selectedCount() {
    return Array.from(this.checkboxElements()).filter((el) => el.checked).length;
  }

  updateState() {
    console.log('[CropSelectController] updateState() called');
    const count = this.selectedCount();
    console.log('[CropSelectController] selectedCount:', count);
    
    if (this.hasCounterTarget) {
      console.log('[CropSelectController] updating counter:', this.counterTarget);
      this.counterTarget.textContent = String(count);
    } else {
      console.warn('[CropSelectController] counter target not found');
    }
    
    if (this.hasSubmitTarget) {
      console.log('[CropSelectController] updating submit button');
      this.submitTarget.disabled = count === 0;
    } else {
      console.warn('[CropSelectController] submit target not found');
    }
    
    if (this.hasHintTarget) {
      console.log('[CropSelectController] updating hint');
      this.hintTarget.style.display = count === 0 ? "block" : "none";
    } else {
      console.warn('[CropSelectController] hint target not found');
    }
  }
}


