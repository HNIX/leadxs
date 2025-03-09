import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="filter"
export default class extends Controller {
  static targets = ["entitySelection", "applyToAll", "fieldSelect", "operatorSelect", "valueField", "betweenFields", "entitySelectionContainer"]
  
  connect() {
    this.toggleEntitySelection()
    this.updateValueFields()
  }
  
  toggleEntitySelection() {
    const applyToAll = this.applyToAllTarget.checked
    this.entitySelectionTarget.disabled = applyToAll
    this.entitySelectionContainerTarget.classList.toggle('opacity-50', applyToAll)
  }
  
  updateValueFields() {
    const operator = this.operatorSelectTarget.value
    const isBetween = operator === 'between'
    
    // Toggle visibility of value field and between fields
    this.valueFieldTarget.classList.toggle('hidden', isBetween)
    this.betweenFieldsTarget.classList.toggle('hidden', !isBetween)
    
    // Update required attributes
    if (isBetween) {
      this.valueFieldTarget.removeAttribute('required')
      this.betweenFieldsTarget.querySelectorAll('input').forEach(input => {
        input.setAttribute('required', 'required')
      })
    } else {
      this.valueFieldTarget.setAttribute('required', 'required')
      this.betweenFieldsTarget.querySelectorAll('input').forEach(input => {
        input.removeAttribute('required')
      })
    }
  }
}