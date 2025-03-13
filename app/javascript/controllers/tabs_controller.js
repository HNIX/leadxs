import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["tab", "panel"]

  connect() {
    // Check for tab parameter in URL
    const urlParams = new URLSearchParams(window.location.search)
    const tabId = urlParams.get('tab')
    
    // If tab parameter exists, find corresponding tab
    if (tabId) {
      const tabs = this.element.querySelectorAll("[data-tabs-target='panel']")
      let tabIndex = -1
      
      // Find index of tab matching the ID in URL
      tabs.forEach((panel, index) => {
        const panelId = this.getPanelId(panel)
        if (panelId === tabId) {
          tabIndex = index
        }
      })
      
      // If found, activate corresponding tab button
      if (tabIndex >= 0 && tabIndex < this.tabTargets.length) {
        this.activate(this.tabTargets[tabIndex])
        return
      }
    }
    
    // Otherwise make sure at least one tab is active
    if (!this.activeTab) {
      this.activate(this.tabTargets[0])
    }
  }

  get activeTab() {
    return this.tabTargets.find(tab => 
      tab.classList.contains("border-indigo-500") && 
      tab.classList.contains("text-indigo-600")
    )
  }
  
  // Method to select a tab by its name/ID
  selectTabByName(event) {
    event.preventDefault()
    const tabName = event.currentTarget.dataset.tab
    
    if (!tabName) return
    
    // Get all tabs and panels
    const tabs = this.tabTargets
    const panels = this.panelTargets
    
    // Find the tab with matching name
    for (let i = 0; i < tabs.length; i++) {
      const tabId = this.getPanelId(panels[i])
      if (tabId === tabName) {
        this.activate(tabs[i])
        return
      }
    }
  }

  select(event) {
    event.preventDefault()
    this.activate(event.currentTarget)
  }

  // Get the ID associated with a panel element
  getPanelId(panel) {
    // Find the index in parent element that might provide IDs for URL updates
    const parentElement = panel.closest('[data-tabs-panels]')
    if (parentElement && parentElement.dataset.tabsPanels) {
      const ids = parentElement.dataset.tabsPanels.split(',')
      const index = parseInt(panel.dataset.tabIndex)
      if (index >= 0 && index < ids.length) {
        return ids[index]
      }
    }
    return panel.dataset.id || panel.dataset.tabIndex
  }

  activate(tab) {
    // Deactivate all tabs
    this.tabTargets.forEach(t => {
      t.classList.remove("border-indigo-500", "text-indigo-600", "dark:text-indigo-400")
      t.classList.add("border-transparent", "text-gray-500", "hover:text-gray-700", "hover:border-gray-300", "dark:text-gray-400", "dark:hover:text-gray-200", "dark:hover:border-gray-600")
    })

    // Activate the selected tab
    tab.classList.remove("border-transparent", "text-gray-500", "hover:text-gray-700", "hover:border-gray-300", "dark:text-gray-400", "dark:hover:text-gray-200", "dark:hover:border-gray-600")
    tab.classList.add("border-indigo-500", "text-indigo-600", "dark:text-indigo-400")

    // Get the tab index
    const index = parseInt(tab.dataset.tabIndex)
    
    // Hide all panels
    this.panelTargets.forEach(panel => {
      panel.classList.add("hidden")
    })

    // Show the panel with matching index
    if (index >= 0 && index < this.panelTargets.length) {
      this.panelTargets[index].classList.remove("hidden")
      
      // Update URL with tab ID if history API is available
      if (history.pushState) {
        const panelId = this.getPanelId(this.panelTargets[index])
        if (panelId) {
          const url = new URL(window.location)
          url.searchParams.set("tab", panelId)
          history.pushState({}, "", url)
        }
      }
    }
  }
}