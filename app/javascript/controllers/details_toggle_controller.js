import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="details-toggle"
export default class extends Controller {
  static targets = ["showText", "hideText", "content"]

  connect() {
    // Make sure we have all required targets
    if (!this.hasShowTextTarget || !this.hasHideTextTarget || !this.hasContentTarget) {
      console.error("Details toggle missing required targets")
    }
  }

  toggle(event) {
    if (event) {
      event.preventDefault()
    }
    
    // Toggle content visibility
    if (this.hasContentTarget) {
      this.contentTarget.classList.toggle("hidden")
    }
    
    // Toggle text visibility
    if (this.hasShowTextTarget && this.hasHideTextTarget) {
      this.showTextTarget.classList.toggle("hidden")
      this.hideTextTarget.classList.toggle("hidden")
    }
  }
}