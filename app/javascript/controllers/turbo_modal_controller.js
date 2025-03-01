import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = []

  connect() {
    // Add ESC key listener for closing the modal
    document.addEventListener('keydown', this.handleKeyDown.bind(this));
    
    // Prevent background scrolling
    document.body.style.overflow = 'hidden';
  }
  
  disconnect() {
    // Remove ESC key listener when modal is destroyed
    document.removeEventListener('keydown', this.handleKeyDown.bind(this));
    
    // Restore background scrolling
    document.body.style.overflow = '';
  }

  close() {
    // Remove the modal from the DOM
    this.element.closest('turbo-frame').innerHTML = '';
  }
  
  handleKeyDown(event) {
    // Close on ESC key
    if (event.key === 'Escape') {
      this.close();
    }
  }
}