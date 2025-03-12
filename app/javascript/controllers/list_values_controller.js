import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["container", "template"]

  connect() {
    this.nextIndex = this.containerTarget.children.length
  }

  addValue(event) {
    event.preventDefault()
    
    // Get the template content
    const template = this.templateTarget.innerHTML
    
    // Replace placeholders with actual values
    const html = template
      .replace(/{index}/g, this.nextIndex)
      .replace(/{position}/g, this.nextIndex + 1)
      
    // Add to container
    this.containerTarget.insertAdjacentHTML('beforeend', html)
    
    // Increment index
    this.nextIndex++
  }
  
  removeValue(event) {
    event.preventDefault()
    
    // Find the button that was clicked
    const button = event.target.closest('button')
    if (!button) return
    
    // Remove this list value field
    const field = button.closest('.list-value-fields')
    if (field) field.remove()
  }
  
  removeExistingValue(event) {
    event.preventDefault()
    
    // Find the button that was clicked
    const button = event.target.closest('button')
    if (!button) return
    
    // Get the row and find destroy checkbox
    const field = button.closest('.list-value-fields')
    if (!field) return
    
    const destroyInput = field.querySelector('input[type="checkbox"]')
    
    // Mark for destruction and hide the row
    if (destroyInput) {
      destroyInput.value = "1"
      destroyInput.checked = true
      field.style.display = 'none'
    } else {
      // If we can't find the destroy checkbox, just remove the row
      field.remove()
    }
  }
}