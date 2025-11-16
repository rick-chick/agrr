import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["submit"]

  connect() {
    this.updateSubmitButton()
    this.#bindCheckboxChangeHandlers()
  }

  selectAll() {
    this.#checkboxes().forEach((checkbox) => {
      checkbox.checked = true
    })
    this.updateSubmitButton()
  }

  deselectAll() {
    this.#checkboxes().forEach((checkbox) => {
      checkbox.checked = false
    })
    this.updateSubmitButton()
  }

  updateSubmitButton() {
    const checkedCount = this.element.querySelectorAll(".field-checkbox:checked").length
    const submitButton = this.submitTarget || this.element.querySelector('input[type="submit"]')
    if (submitButton) submitButton.disabled = checkedCount === 0
  }

  #checkboxes() {
    return this.element.querySelectorAll(".field-checkbox")
  }

  #bindCheckboxChangeHandlers() {
    this.#checkboxes().forEach((checkbox) => {
      checkbox.addEventListener("change", () => this.updateSubmitButton())
    })
  }
}

