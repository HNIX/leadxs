import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="toggle"
export default class extends Controller {
  static targets = ["toggleable", "controller", "content", "icon"]
  static values = { show: { type: Boolean, default: false } }

  connect() {
    this.updateVisibility()
    this.updateIcon()
    
    // Check localStorage to see if this toggle was previously open
    const storedState = localStorage.getItem(`toggle-${this.identifier}`)
    if (storedState === "open") {
      this.showValue = true
      this.toggle()
    }
  }

  toggle() {
    this.showValue = !this.showValue
    this.updateVisibility()
    this.updateIcon()
    
    // Store state in localStorage
    localStorage.setItem(`toggle-${this.identifier}`, this.showValue ? "open" : "closed")
  }

  showValueChanged() {
    this.updateVisibility()
    this.updateIcon()
  }
  
  updateIcon() {
    if (!this.hasIconTarget) return
    
    const openClasses = this.iconTarget.dataset.openClasses?.split(' ') || []
    const closedClasses = this.iconTarget.dataset.closedClasses?.split(' ') || []
    
    if (this.showValue) {
      closedClasses.forEach(cls => this.iconTarget.classList.remove(cls))
      openClasses.forEach(cls => this.iconTarget.classList.add(cls))
    } else {
      openClasses.forEach(cls => this.iconTarget.classList.remove(cls))
      closedClasses.forEach(cls => this.iconTarget.classList.add(cls))
    }
  }

  updateVisibility() {
    // Handle content target specifically for simple toggles
    if (this.hasContentTarget) {
      if (this.showValue) {
        this.contentTarget.classList.remove('hidden')
        this.contentTarget.classList.add('block')
      } else {
        this.contentTarget.classList.remove('block')
        this.contentTarget.classList.add('hidden')
      }
    }
    
    // Handle the original toggleable functionality
    if (!this.hasToggleableTarget) return
    
    const controllerValue = this.hasControllerTarget ? this.controllerTarget.value : null
    
    this.toggleableTargets.forEach(target => {
      const showIf = target.dataset.toggleShowIf
      const activeClass = target.dataset.toggleActiveClass || "block"
      const inactiveClass = target.dataset.toggleInactiveClass || "hidden"
      
      if (showIf) {
        const values = showIf.split(',')
        const shouldShow = controllerValue ? values.includes(controllerValue) : this.showValue
        
        if (shouldShow) {
          target.classList.remove(inactiveClass)
          target.classList.add(activeClass)
        } else {
          target.classList.remove(activeClass)
          target.classList.add(inactiveClass)
        }
      }
    })
  }
}