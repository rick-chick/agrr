import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["card", "inputContainer"]
  static values = {
    inputName: String
  }

  initialize() {
    this.selectedIds = new Set()
  }

  connect() {
    this.cardTargets.forEach((card) => {
      const cropId = card.dataset.cropId
      if (!cropId) {
        return
      }

      if (card.dataset.selected === "true") {
        card.classList.add("is-selected")
        this.selectedIds.add(cropId)
      } else {
        card.classList.remove("is-selected")
      }
    })

    if (this.hasInputContainerTarget) {
      const selector = `input[name="${this.inputFieldName}"]`
      const existingInputs = this.inputContainerTarget.querySelectorAll(selector)

      existingInputs.forEach((input) => {
        if (input.value) {
          this.selectedIds.add(input.value)
        }
      })

      this.refreshInputs()
    }
  }

  toggle(event) {
    event.preventDefault()
    const card = event.currentTarget
    const cropId = card.dataset.cropId

    if (!cropId) {
      return
    }

    if (this.selectedIds.has(cropId)) {
      this.selectedIds.delete(cropId)
      card.classList.remove("is-selected")
      card.dataset.selected = "false"
    } else {
      this.selectedIds.add(cropId)
      card.classList.add("is-selected")
      card.dataset.selected = "true"
    }

    this.refreshInputs()
  }

  refreshInputs() {
    if (!this.hasInputContainerTarget) {
      return
    }

    const container = this.inputContainerTarget
    container.innerHTML = ""

    Array.from(this.selectedIds)
      .sort((a, b) => parseInt(a, 10) - parseInt(b, 10))
      .forEach((id) => {
        const input = document.createElement("input")
        input.type = "hidden"
        input.name = this.inputFieldName
        input.value = id
        container.appendChild(input)
      })
  }

  clearSelection() {
    this.selectedIds.clear()

    this.cardTargets.forEach((card) => {
      card.classList.remove("is-selected")
      card.dataset.selected = "false"
    })

    this.refreshInputs()
  }

  get inputFieldName() {
    if (this.hasInputNameValue && this.inputNameValue) {
      return this.inputNameValue
    }

    return "selected_crop_ids[]"
  }
}

