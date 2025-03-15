import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="toggle"
export default class extends Controller {
  static targets = ["toggleable", "controller", "content", "icon"]
  static values = { 
    show: { type: Boolean, default: false },
    identifier: { type: String, default: '' }
  }

  connect() {
    this.updateVisibility()
    this.updateIcon()
    
    // Check localStorage to see if this toggle was previously open
    const toggleId = this.identifierValue || this.element.id || this.identifier
    const storedState = localStorage.getItem(`toggle-${toggleId}`)
    if (storedState === "open") {
      this.showValue = true
      this.updateVisibility()
      this.updateIcon()
    }
    
    // Add click outside handler for dropdowns
    if (this.element.classList.contains('dropdown')) {
      this.clickOutsideHandler = this.handleClickOutside.bind(this)
      document.addEventListener('click', this.clickOutsideHandler)
      
      // Stop propagation for clicks inside content
      if (this.hasContentTarget) {
        this.contentTarget.addEventListener('click', this.preventPropagation.bind(this))
      }
    }
  }
  
  disconnect() {
    // Clean up event listeners
    if (this.clickOutsideHandler) {
      document.removeEventListener('click', this.clickOutsideHandler)
    }
    
    if (this.hasContentTarget && this.element.classList.contains('dropdown')) {
      this.contentTarget.removeEventListener('click', this.preventPropagation)
    }
  }
  
  preventPropagation(event) {
    event.stopPropagation()
  }
  
  handleClickOutside(event) {
    // Close dropdown when clicking outside
    if (this.showValue && !this.element.contains(event.target)) {
      this.showValue = false
      this.updateVisibility()
      this.updateIcon()
    }
  }

  toggle(event) {
    // Prevent event from bubbling up to document
    if (event) {
      event.stopPropagation()
    }
    
    this.showValue = !this.showValue
    this.updateVisibility()
    this.updateIcon()
    
    // Store state in localStorage
    const toggleId = this.identifierValue || this.element.id || this.identifier
    localStorage.setItem(`toggle-${toggleId}`, this.showValue ? "open" : "closed")
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