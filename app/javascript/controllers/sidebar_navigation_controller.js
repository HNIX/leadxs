import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["navItem", "section"]

  connect() {
    console.log("Sidebar navigation controller connected", {
      navItemTargets: this.navItemTargets.length, 
      sectionTargets: this.sectionTargets.length
    })
    
    // Restore section from URL hash if present
    const hash = window.location.hash.replace('#', '')
    
    if (hash && this.isSectionValid(hash)) {
      console.log("Using hash from URL:", hash)
      this.switchToSection(hash)
    } else {
      // Default to first section
      if (this.sectionTargets.length > 0) {
        const firstSection = this.sectionTargets[0].dataset.section
        console.log("Using first section:", firstSection)
        this.switchToSection(firstSection)
      } else {
        console.error("No section targets found!")
      }
    }
    
    // Listen for hash changes
    window.addEventListener('hashchange', this.handleHashChange.bind(this))
  }
  
  disconnect() {
    window.removeEventListener('hashchange', this.handleHashChange.bind(this))
  }
  
  handleHashChange() {
    const hash = window.location.hash.replace('#', '')
    if (hash && this.isSectionValid(hash)) {
      this.switchToSection(hash)
    }
  }
  
  isSectionValid(section) {
    return this.sectionTargets.some(el => el.dataset.section === section)
  }
  
  switchSection(event) {
    event.preventDefault()
    console.log("switchSection called from event", event.currentTarget)
    const section = event.currentTarget.dataset.section
    console.log("Switching to section:", section)
    this.switchToSection(section)
    
    // Update URL hash
    window.history.replaceState(null, null, `#${section}`)
  }
  
  switchToSection(section) {
    console.log("switchToSection called with:", section)
    
    // Update navigation buttons
    this.navItemTargets.forEach(navItem => {
      const isActive = navItem.dataset.section === section
      console.log("Nav item:", navItem.dataset.section, "isActive:", isActive)
      
      // Active state
      if (isActive) {
        navItem.classList.add("text-indigo-600", "bg-gray-50", "dark:bg-gray-800", "dark:text-indigo-400")
        navItem.classList.remove("text-gray-700", "hover:bg-gray-50", "hover:text-indigo-600", "dark:text-gray-300", "dark:hover:bg-gray-800", "dark:hover:text-indigo-400")
        
        // Update icon color
        const icon = navItem.querySelector("svg")
        if (icon) {
          icon.classList.add("text-indigo-600", "dark:text-indigo-400")
          icon.classList.remove("text-gray-400", "group-hover:text-indigo-600", "dark:text-gray-500", "dark:group-hover:text-indigo-400")
        }
      } 
      // Inactive state
      else {
        navItem.classList.remove("text-indigo-600", "bg-gray-50", "dark:bg-gray-800", "dark:text-indigo-400")
        navItem.classList.add("text-gray-700", "hover:bg-gray-50", "hover:text-indigo-600", "dark:text-gray-300", "dark:hover:bg-gray-800", "dark:hover:text-indigo-400")
        
        // Update icon color
        const icon = navItem.querySelector("svg")
        if (icon) {
          icon.classList.remove("text-indigo-600", "dark:text-indigo-400")
          icon.classList.add("text-gray-400", "group-hover:text-indigo-600", "dark:text-gray-500", "dark:group-hover:text-indigo-400")
        }
      }
    })
    
    // Show/hide content sections
    this.sectionTargets.forEach(sectionEl => {
      if (sectionEl.dataset.section === section) {
        sectionEl.classList.remove("hidden")
        sectionEl.classList.add("block")
      } else {
        sectionEl.classList.add("hidden")
        sectionEl.classList.remove("block")
      }
    })
    
    // Dispatch events for other controllers to respond to section changes
    
    // Specific namespaced event for direct controller communication
    const sidebarEvent = new CustomEvent("sidebar-navigation:section-changed", { 
      detail: { section: section },
      bubbles: true
    })
    this.element.dispatchEvent(sidebarEvent)
    
    // Generic event for any controller that needs to know about section changes
    const genericEvent = new CustomEvent("section-changed", { 
      detail: { section: section },
      bubbles: true
    })
    this.element.dispatchEvent(genericEvent)
  }
}