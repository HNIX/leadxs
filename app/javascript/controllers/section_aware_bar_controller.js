import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["bar"]
  static values = { visibleSections: Array }

  connect() {
    console.log("Section aware bar controller connected")
    console.log("Visible sections:", this.visibleSectionsValue)
    
    // Add event listener for sidebar navigation changes
    document.addEventListener("sidebar-navigation:section-changed", this.handleSectionChange.bind(this))
    
    // Initial check of current section
    this.checkCurrentSection()
  }
  
  disconnect() {
    document.removeEventListener("sidebar-navigation:section-changed", this.handleSectionChange.bind(this))
  }
  
  handleSectionChange(event) {
    const currentSection = event.detail.section
    console.log("Section changed to:", currentSection)
    this.updateBarVisibility(currentSection)
  }
  
  checkCurrentSection() {
    // Find the active section
    const activeSection = document.querySelector('[data-sidebar-navigation-target="section"]:not(.hidden)')
    if (activeSection) {
      const sectionId = activeSection.dataset.section
      console.log("Initial active section:", sectionId)
      this.updateBarVisibility(sectionId)
    }
  }
  
  updateBarVisibility(currentSection) {
    if (this.visibleSectionsValue.includes(currentSection)) {
      console.log("Showing sticky bar for section:", currentSection)
      this.barTarget.classList.remove("hidden")
    } else {
      console.log("Hiding sticky bar for section:", currentSection)
      this.barTarget.classList.add("hidden")
    }
  }
}