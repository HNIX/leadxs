import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["container", "template"]

  connect() {
    // Ensure we have at least one list value field when the form loads
    if (this.element.querySelectorAll('.list-value-item').length === 0) {
      this.add();
    }
  }

  add(event) {
    if (event) event.preventDefault();
    
    // Find the container to add the new list value
    const container = this.element.closest('form').querySelector('.list-values-container');
    if (!container) return;
    
    // Get the template and create a new list value row
    const template = document.getElementById('list-value-template');
    if (!template) return;
    
    // Generate a unique index for the new row
    const newIndex = new Date().getTime();
    
    // Create the new row from the template
    let newRow = template.innerHTML.replace(/NEW_RECORD/g, newIndex);
    
    // Create a temporary element to properly create DOM nodes
    const tempDiv = document.createElement('div');
    tempDiv.innerHTML = newRow;
    
    // Add the new row to the container
    container.appendChild(tempDiv.firstElementChild);
  }

  remove(event) {
    console.log("test")

    if (event) event.preventDefault();

    // Find the list value item to remove
    const item = event.currentTarget.closest('.list-value-item');
    if (!item) return;
    
    // Check if this is an existing record that needs to be marked for destruction
    const destroyCheckbox = item.querySelector('.destroy-checkbox');
    
    if (destroyCheckbox) {
      // Mark for destruction and hide
      destroyCheckbox.checked = true;
      item.style.display = 'none';
    } else {
      // Simply remove from DOM for new records
      item.remove();
    }
  }
}