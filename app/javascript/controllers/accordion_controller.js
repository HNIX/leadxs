import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["section", "content", "icon"]

  connect() {
    // Optional: Automatically open the first section
    if (this.sectionTargets.length > 0) {
      this.toggle({ currentTarget: this.sectionTargets[0] })
    }
  }

  toggle(event) {
    const sectionId = event.currentTarget.dataset.sectionId
    
    // Toggle the content visibility
    this.contentTargets.forEach(content => {
      if (content.dataset.sectionId === sectionId) {
        content.classList.toggle('hidden')
      }
    })
    
    // Rotate the icon
    this.iconTargets.forEach(icon => {
      if (icon.dataset.sectionId === sectionId) {
        icon.classList.toggle('rotate-180')
      }
    })
  }
}