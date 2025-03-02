import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="toggle"
export default class extends Controller {
  static targets = ["toggleable", "controller"]
  static values = { show: Boolean }

  connect() {
    this.updateVisibility()
  }

  toggle() {
    this.updateVisibility()
  }

  showValueChanged() {
    this.updateVisibility()
  }

  updateVisibility() {
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