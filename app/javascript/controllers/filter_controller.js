import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="filter"
export default class extends Controller {
  static targets = ["entitySelection", "applyToAll", "fieldSelect", "operatorSelect", "valueField", "betweenFields", "entitySelectionContainer"]
  
  connect() {
    // Only call these methods if the targets exist
    if (this.hasEntitySelectionTarget && this.hasApplyToAllTarget) {
      this.toggleEntitySelection()
    }
    
    if (this.hasOperatorSelectTarget && this.hasValueFieldTarget && this.hasBetweenFieldsTarget) {
      this.updateValueFields()
    }
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
  
  toggleCustomDateRange(event) {
    const customDateRange = document.getElementById('customDateRange')
    if (!customDateRange) return
    
    if (event.target.value === 'custom') {
      customDateRange.classList.remove('hidden')
    } else {
      customDateRange.classList.add('hidden')
      
      // If a preset is selected, set start/end dates and submit form
      if (event.target.value !== '') {
        const daysAgo = parseInt(event.target.value)
        if (!isNaN(daysAgo)) {
          const endDate = new Date()
          const startDate = new Date()
          startDate.setDate(endDate.getDate() - daysAgo)
          
          // Find the form inputs and set their values
          const startDateInput = this.element.querySelector('input[name="start_date"]')
          const endDateInput = this.element.querySelector('input[name="end_date"]')
          
          if (startDateInput && endDateInput) {
            startDateInput.value = this.formatDate(startDate)
            endDateInput.value = this.formatDate(endDate)
            
            // Submit the form to apply the selected date range
            this.element.requestSubmit()
          }
        }
      }
    }
  }
  
  // Helper to format dates as YYYY-MM-DD
  formatDate(date) {
    const year = date.getFullYear()
    const month = String(date.getMonth() + 1).padStart(2, '0')
    const day = String(date.getDate()).padStart(2, '0')
    return `${year}-${month}-${day}`
  }
}