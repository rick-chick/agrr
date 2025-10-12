import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["sizeInput"]
  
  selectSize(event) {
    event.preventDefault()
    
    const sizeId = event.currentTarget.dataset.sizeId
    this.sizeInputTarget.value = sizeId
    
    // フォームを送信
    this.element.requestSubmit()
  }
}

