import { Controller } from "@hotwired/stimulus"

// Dropdown controller for navigation dropdown menus
export default class extends Controller {
  static targets = ["toggle", "menu"]

  connect() {
    this.isOpen = false
    // Close dropdown when clicking outside
    this.boundClickOutside = this.clickOutside.bind(this)
    document.addEventListener("click", this.boundClickOutside)
  }

  disconnect() {
    document.removeEventListener("click", this.boundClickOutside)
  }

  toggle(event) {
    event.stopPropagation()
    this.isOpen = !this.isOpen
    this.updateMenu()
  }

  close() {
    this.isOpen = false
    this.updateMenu()
  }

  updateMenu() {
    if (this.isOpen) {
      this.element.setAttribute("data-dropdown-open", "true")
    } else {
      this.element.removeAttribute("data-dropdown-open")
    }
  }

  clickOutside(event) {
    if (!this.element.contains(event.target)) {
      this.close()
    }
  }
}

