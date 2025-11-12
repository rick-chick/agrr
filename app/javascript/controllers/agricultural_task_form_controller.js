import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["referenceToggle"]

  toggleReferenceFlag(event) {
    if (!event || !event.target) {
      return
    }

    this.clearCropSelections()
  }

  clearCropSelections() {
    const cropSelectorElements = this.element.querySelectorAll(
      '[data-controller~="crop-selector"]'
    )

    cropSelectorElements.forEach((element) => {
      const controller = this.application.getControllerForElementAndIdentifier(
        element,
        "crop-selector"
      )

      if (controller && typeof controller.clearSelection === "function") {
        controller.clearSelection()
        return
      }

      this.resetSelectionFallback(element)
    })
  }

  resetSelectionFallback(rootElement) {
    const cards = rootElement.querySelectorAll('[data-role="crop-card"]')
    cards.forEach((card) => {
      card.classList.remove("is-selected")
      card.dataset.selected = "false"
    })

    const container = rootElement.querySelector(
      '[data-crop-selector-target="inputContainer"]'
    )
    if (container) {
      container.innerHTML = ""
    }
  }
}

