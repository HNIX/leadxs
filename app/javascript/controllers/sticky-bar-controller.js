import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["bar", "sectionName", "submitButton"]
  static values = {
    visibleSections: Array
  }

  connect() {
    this.handleScroll = this.handleScroll.bind(this)
    window.addEventListener('scroll', this.handleScroll)
    this.handleScroll()

    // Listen for section changes from the sidebar navigation
    document.addEventListener('section-changed', this.handleSectionChange.bind(this))
  }

  disconnect() {
    window.removeEventListener('scroll', this.handleScroll)
  }

  handleScroll() {
    if (window.scrollY > 100) {
      this.barTarget.classList.remove('hidden')
    } else {
      this.barTarget.classList.add('hidden')
    }
  }

  handleSectionChange(event) {
    const section = event.detail.section
    
    // Check if this section should show the sticky bar
    const shouldShowBar = this.visibleSectionsValue.includes(section)
    
    if (shouldShowBar) {
      this.barTarget.classList.remove('hidden')
      if (this.hasSectionNameTarget) {
        this.sectionNameTarget.textContent = this.getSectionTitle(section)
      }
      
      // Update submit button to target the correct form
      if (this.hasSubmitButtonTarget) {
        this.submitButtonTarget.setAttribute('data-section', section)
      }
    } else {
      this.barTarget.classList.add('hidden')
    }
  }

  // Convert section ID to a readable title
  getSectionTitle(section) {
    const titles = {
      'basic-info': 'Basic Information',
      'advanced': 'Advanced Settings',
      'bidding': 'Bidding Configuration'
    }
    return titles[section] || 'Configuration'
  }

  submitActiveForm(event) {
    event.preventDefault()
    
    // Get the active section from the button's data attribute
    const section = event.currentTarget.getAttribute('data-section')
    
    // Find the form to submit based on the active section
    let formId
    switch(section) {
      case 'basic-info':
        formId = 'campaign-form'
        break
      case 'advanced':
        formId = 'campaign-advanced-form'
        break
      case 'bidding':
        formId = 'campaign-bidding-form'
        break
      default:
        formId = 'campaign-form'
    }
    
    const form = document.getElementById(formId)
    if (form) {
      form.submit()
    } else {
      console.error(`Form with ID ${formId} not found`)
    }
  }
}