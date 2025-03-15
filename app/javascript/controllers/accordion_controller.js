import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["content", "icon"]

  connect() {
    // Initialize
  }

  toggle() {
    // Toggle the content visibility
    this.contentTarget.classList.toggle('hidden')
    
    // Rotate the icon
    this.iconTarget.classList.toggle('rotate-180')
  }
}