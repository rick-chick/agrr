import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="stop-propagation"
// または data-action="click->stop-propagation#stop"
export default class extends Controller {
  stop(event) {
    event.stopPropagation()
  }
}

