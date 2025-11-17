import { Controller } from "@hotwired/stimulus"

// Navbar controller for mobile menu toggle
export default class extends Controller {
  static targets = ["menu", "toggle"]

  connect() {
    this.isOpen = false
    // Initialize aria attributes
    this.updateMenu()
    // Close menu when clicking outside
    this.boundClickOutside = this.clickOutside.bind(this)
    document.addEventListener("click", this.boundClickOutside)
  }

  disconnect() {
    document.removeEventListener("click", this.boundClickOutside)
  }

  toggle(event) {
    if (event) {
      event.stopPropagation()
    }
    this.isOpen = !this.isOpen
    this.updateMenu()
  }

  close() {
    this.isOpen = false
    this.updateMenu()
  }

  updateMenu() {
    const menuId = this.menuTarget.id || "navbar-menu"
    if (!this.menuTarget.id) {
      this.menuTarget.id = menuId
    }
    
    if (this.isOpen) {
      this.element.setAttribute("data-navbar-open", "true")
      this.toggleTarget.setAttribute("aria-expanded", "true")
      this.toggleTarget.setAttribute("aria-controls", menuId)
    } else {
      this.element.removeAttribute("data-navbar-open")
      this.toggleTarget.setAttribute("aria-expanded", "false")
      this.toggleTarget.setAttribute("aria-controls", menuId)
    }
  }

  // Close menu when clicking outside
  clickOutside(event) {
    if (this.isOpen && !this.element.contains(event.target)) {
      this.close()
    }
  }
}

