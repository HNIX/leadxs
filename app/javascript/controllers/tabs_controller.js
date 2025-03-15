import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["tab", "panel"]

  connect() {
    console.log("Tabs controller connected", this.tabTargets, this.panelTargets);
    
    // Check for tab parameter in URL
    const urlParams = new URLSearchParams(window.location.search)
    const tabId = urlParams.get('tab')
    
    // If tab parameter exists, find corresponding tab
    if (tabId) {
      let tabIndex = -1
      
      // Try to find the tab index from panels
      this.panelTargets.forEach((panel, index) => {
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
    if (!this.activeTab && this.tabTargets.length > 0) {
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
    console.log("Activating tab", tab, tab.dataset.tabIndex);
    
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
    
    // Hide all panels with animation
    this.panelTargets.forEach(panel => {
      panel.classList.add("opacity-0")
      // Use a slight delay before hiding to allow animation
      setTimeout(() => {
        panel.classList.add("hidden")
      }, 200)
    })

    // Show the panel with matching index
    if (index >= 0 && index < this.panelTargets.length) {
      const panel = this.panelTargets[index]
      
      // Small delay to ensure previous panel hide animation has started
      setTimeout(() => {
        panel.classList.remove("hidden")
        // Force a reflow to ensure transition works
        panel.offsetHeight
        panel.classList.remove("opacity-0")
        panel.classList.add("opacity-100")
      }, 250)
      
      // Update URL with tab ID if history API is available
      if (history.pushState) {
        const panelId = this.getPanelId(panel)
        if (panelId) {
          const url = new URL(window.location)
          url.searchParams.set("tab", panelId)
          history.pushState({}, "", url)
        }
      }
    }
  }
}