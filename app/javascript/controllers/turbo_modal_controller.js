import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["modal"]

  connect() {
    console.log("Turbo modal controller connected");
    
    // Add ESC key listener for closing the modal
    document.addEventListener('keydown', this.handleKeyDown.bind(this));
    
    // Add event listener for turbo:submit-end
    document.addEventListener("turbo:submit-end", this.handleFormSubmission.bind(this));
    
    // Prevent background scrolling
    document.body.style.overflow = 'hidden';
  }
  
  disconnect() {
    // Remove ESC key listener when modal is destroyed
    document.removeEventListener('keydown', this.handleKeyDown.bind(this));
    
    // Remove event listener for form submissions
    document.removeEventListener("turbo:submit-end", this.handleFormSubmission.bind(this));
    
    // Restore background scrolling
    document.body.style.overflow = '';
  }

  close() {
    // Remove the modal from the DOM
    this.element.closest('turbo-frame').innerHTML = '';
  }
  
  hideModal() {
    this.close();
  }
  
  handleKeyDown(event) {
    // Close on ESC key
    if (event.key === 'Escape') {
      this.close();
    }
  }
  
  // Handle backdrop clicks to close the modal
  backdropClose(event) {
    // Only close if clicking directly on the backdrop, not on modal content
    if (event.target === event.currentTarget) {
      this.close();
    }
  }
  
  // Handle form submissions
  handleFormSubmission(event) {
    if (event.detail.success) {
      this.close();
    }
  }
}