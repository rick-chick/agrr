// Connects to data-controller="pest-form"
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["methodsContainer"]

  connect() {
    this.ensureInitialized()
  }

  ensureInitialized() {
    // Delegate click for remove buttons inside container
    this.removeHandler = (e) => {
      const removeBtn = e.target.closest('.remove-control-method')
      if (!removeBtn) return
      e.preventDefault()
      this.removeControlMethod(removeBtn)
    }
    this.methodsContainerTarget?.addEventListener('click', this.removeHandler)
  }

  disconnect() {
    this.methodsContainerTarget?.removeEventListener('click', this.removeHandler)
  }

  addControlMethod(e) {
    e.preventDefault()
    const index = this.nextMethodIndex()
    const template = this.buildMethodTemplate(index)
    this.methodsContainerTarget.insertAdjacentHTML('beforeend', template)
  }

  removeControlMethod(button) {
    const item = button.closest('.control-method-fields')
    if (!item) return
    const destroyFlag = item.querySelector('.destroy-flag')
    if (destroyFlag) {
      destroyFlag.value = 'true'
      item.style.display = 'none'
    } else {
      item.remove()
    }
  }

  nextMethodIndex() {
    const all = this.methodsContainerTarget.querySelectorAll('.control-method-fields')
    let visibleCount = 0
    all.forEach((el) => {
      const flag = el.querySelector('.destroy-flag')
      const hidden = el.style.display === 'none'
      const destroyed = flag && flag.value === 'true'
      if (!hidden && !destroyed) visibleCount += 1
    })
    return visibleCount
  }

  buildMethodTemplate(index) {
    // i18n strings from data attributes on form root
    const t = (key) => this.element.getAttribute(`data-i18n-${key}`) || ''
    return `
      <div class="control-method-fields nested-fields">
        <div class="nested-fields-header">
          <h4 class="nested-title">${t('control-methods-title')}</h4>
          <button type="button" class="btn btn-error btn-sm remove-control-method">
            ${t('remove-method')}
          </button>
        </div>
        <div class="form-group">
          <label class="form-label">${t('method-type-label')}</label>
          <select name="pest[pest_control_methods_attributes][${index}][method_type]" class="form-control">
            <option value="">${t('select-method-type')}</option>
            <option value="chemical">${t('method-types-chemical')}</option>
            <option value="biological">${t('method-types-biological')}</option>
            <option value="cultural">${t('method-types-cultural')}</option>
            <option value="physical">${t('method-types-physical')}</option>
          </select>
        </div>
        <div class="form-group">
          <label class="form-label">${t('method-name-label')}</label>
          <input type="text" name="pest[pest_control_methods_attributes][${index}][method_name]" class="form-control">
        </div>
        <div class="form-group">
          <label class="form-label">${t('method-description-label')}</label>
          <textarea name="pest[pest_control_methods_attributes][${index}][description]" rows="3" class="form-control"></textarea>
        </div>
        <div class="form-group">
          <label class="form-label">${t('timing-hint-label')}</label>
          <input type="text" name="pest[pest_control_methods_attributes][${index}][timing_hint]" class="form-control">
        </div>
      </div>
    `
  }
}


