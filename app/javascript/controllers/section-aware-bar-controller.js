import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["bar"]
  static values = {
    visibleSections: Array
  }

  connect() {
    // Listen for section changes from the sidebar navigation
    document.addEventListener('section-changed', this.handleSectionChange.bind(this))
    
    // Check if there's an initial section in the URL
    this.checkInitialSection()
  }

  disconnect() {
    document.removeEventListener('section-changed', this.handleSectionChange)
  }

  checkInitialSection() {
    // Get section from URL if present
    const urlParams = new URLSearchParams(window.location.search)
    const section = urlParams.get('section')
    
    if (section) {
      this.updateBarForSection(section)
    }
  }

  handleSectionChange(event) {
    const section = event.detail.section
    this.updateBarForSection(section)
  }
  
  updateBarForSection(section) {
    // Check if this section should show the sticky bar
    const shouldShowBar = this.visibleSectionsValue.includes(section)
    
    if (shouldShowBar) {
      this.barTarget.classList.remove('hidden')
    } else {
      this.barTarget.classList.add('hidden')
    }
  }

  submitActiveForm() {
    // Since we have a single form (campaign-form) that includes all fields,
    // we can simply submit it regardless of which section we're in
    const form = document.getElementById('campaign-form')
    if (form) {
      form.submit()
    } else {
      console.error('Form not found')
    }
  }
}