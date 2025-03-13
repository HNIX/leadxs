import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["tab", "panel"]

  connect() {
    // Check which tab to show based on the hash in the URL or default to first tab
    this.showTabFromHash() || this.showTab(0)
  }

  change(event) {
    event.preventDefault()
    
    // Get the index of the tab that was clicked
    const clickedTab = event.currentTarget
    const index = this.tabTargets.indexOf(clickedTab)
    
    if (index !== -1) {
      this.showTab(index)
      
      // Update the URL hash without scrolling
      const hash = clickedTab.getAttribute('href')
      if (hash) {
        history.replaceState(null, null, hash)
      }
    }
  }

  showTabFromHash() {
    if (window.location.hash) {
      const tabWithHash = this.tabTargets.find(tab => 
        tab.getAttribute('href') === window.location.hash
      )
      
      if (tabWithHash) {
        const index = this.tabTargets.indexOf(tabWithHash)
        this.showTab(index)
        return true
      }
    }
    return false
  }

  showTab(index) {
    this.tabTargets.forEach((tab, i) => {
      // Update the tab styles
      if (i === index) {
        tab.classList.remove('border-transparent', 'text-gray-500', 'hover:text-gray-700', 'dark:text-gray-400', 'dark:hover:text-gray-300')
        tab.classList.add('border-blue-500', 'text-blue-600', 'dark:text-blue-400')
      } else {
        tab.classList.add('border-transparent', 'text-gray-500', 'hover:text-gray-700', 'dark:text-gray-400', 'dark:hover:text-gray-300')
        tab.classList.remove('border-blue-500', 'text-blue-600', 'dark:text-blue-400')
      }
    })

    this.panelTargets.forEach((panel, i) => {
      // Show/hide the panel
      if (i === index) {
        panel.classList.remove('hidden')
      } else {
        panel.classList.add('hidden')
      }
    })
  }
}