import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["bar", "container"]
  static values = {
    threshold: { type: Number, default: 100 }, // Scroll threshold to show the bar
    hidden: { type: Boolean, default: false }, // Whether the bar is hidden when page loads
    offset: { type: Number, default: 0 } // Additional offset from bottom
  }

  connect() {
    console.log("Sticky bar controller connected")
    // Since we're not using fixed positioning anymore, we don't need to handle scroll
    // or update container padding
    
    // Just ensure the bar is visible by default
    this.showBar()
  }

  disconnect() {
    console.log("Sticky bar controller disconnected")
  }
  
  showBar() {
    if (!this.hasBarTarget) return
    
    // Make sure bar is visible
    this.barTarget.classList.remove('translate-y-full')
    this.barTarget.classList.add('translate-y-0')
  }
  
  hideBar() {
    if (!this.hasBarTarget) return
    
    this.barTarget.classList.add('translate-y-full')
    this.barTarget.classList.remove('translate-y-0')
  }
}