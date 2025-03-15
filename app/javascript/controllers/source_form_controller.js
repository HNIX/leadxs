import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [
    "tabButton", 
    "tabContent", 
    "helpContent", 
    "prevButton", 
    "nextButton", 
    "submitButton",
    "payoutMethodSelect", 
    "payoutGroup", 
    "marginGroup",
    "progressBar",
    "progressFill",
    "requiredField",
    "draftField",
    "allTabs"
  ]

  connect() {
    // Set initial state based on selected value
    this.toggleFields()
    
    // Initialize the form
    this.currentTabIndex = 0
    this.tabs = ["basic", "api", "postback", "security"]
    this.updateTabDisplay()
    this.updateProgress()

    // Setup event listeners for required fields
    if (this.hasRequiredFieldTarget) {
      this.requiredFieldTargets.forEach(field => {
        field.addEventListener('input', () => this.updateProgress())
      })
    }
  }

  // Switch to the next tab
  nextTab(event) {
    event.preventDefault()
    
    if (this.currentTabIndex < this.tabs.length - 1) {
      this.currentTabIndex++
      this.updateTabDisplay()
    }
  }

  // Switch to the previous tab
  prevTab(event) {
    event.preventDefault()
    
    if (this.currentTabIndex > 0) {
      this.currentTabIndex--
      this.updateTabDisplay()
    }
  }

  // Update the display of tabs, buttons, and content
  updateTabDisplay() {
    const currentTab = this.tabs[this.currentTabIndex]
    
    // Update tab buttons
    this.tabButtonTargets.forEach(button => {
      const buttonTab = button.dataset.tab
      if (buttonTab === currentTab) {
        button.classList.add("text-blue-600", "dark:text-blue-400", "border-blue-600", "dark:border-blue-400")
        button.classList.remove("text-gray-500", "hover:text-gray-700", "dark:text-gray-400", "dark:hover:text-gray-300", "border-transparent", "hover:border-gray-300", "dark:hover:border-gray-600")
      } else {
        button.classList.remove("text-blue-600", "dark:text-blue-400", "border-blue-600", "dark:border-blue-400")
        button.classList.add("text-gray-500", "hover:text-gray-700", "dark:text-gray-400", "dark:hover:text-gray-300", "border-transparent", "hover:border-gray-300", "dark:hover:border-gray-600")
      }
    })
    
    // Update tab content
    this.tabContentTargets.forEach(content => {
      if (content.dataset.tab === currentTab) {
        content.classList.remove("hidden")
      } else {
        content.classList.add("hidden")
      }
    })
    
    // Update help content
    this.helpContentTargets.forEach(content => {
      if (content.dataset.tab === currentTab) {
        content.classList.remove("hidden")
      } else {
        content.classList.add("hidden")
      }
    })
    
    // Update navigation buttons
    if (this.currentTabIndex > 0) {
      this.prevButtonTarget.classList.remove("hidden")
    } else {
      this.prevButtonTarget.classList.add("hidden")
    }
    
    if (this.currentTabIndex === this.tabs.length - 1) {
      this.nextButtonTarget.classList.add("hidden")
      this.submitButtonTarget.classList.remove("hidden")
    } else {
      this.nextButtonTarget.classList.remove("hidden")
      this.submitButtonTarget.classList.add("hidden")
    }
  }

  // Handle tab button clicks directly
  selectTab(event) {
    const tab = event.currentTarget.dataset.tab
    const index = this.tabs.indexOf(tab)
    
    if (index !== -1) {
      this.currentTabIndex = index
      this.updateTabDisplay()
    }
  }

  // Toggle payout fields based on payout method
  toggleFields() {
    const selectedMethod = this.payoutMethodSelectTarget.value
    
    if (selectedMethod === "percentage") {
      this.marginGroupTarget.classList.remove("hidden")
      this.payoutGroupTarget.classList.add("hidden")
    } else if (selectedMethod === "fixed") {
      this.marginGroupTarget.classList.add("hidden")
      this.payoutGroupTarget.classList.remove("hidden")
    } else {
      // If nothing is selected, hide both
      this.marginGroupTarget.classList.add("hidden")
      this.payoutGroupTarget.classList.add("hidden")
    }
  }

  // Update progress bar based on required fields completion
  updateProgress() {
    if (!this.hasProgressFillTarget || !this.hasRequiredFieldTarget) return
    
    const requiredFields = this.requiredFieldTargets
    const completedFields = requiredFields.filter(field => field.value.trim() !== '')
    const progressPercentage = Math.round((completedFields.length / requiredFields.length) * 100)
    
    this.progressFillTarget.style.width = `${progressPercentage}%`
    
    // Update progress bar color based on completion
    if (progressPercentage < 30) {
      this.progressFillTarget.classList.remove('bg-yellow-500', 'bg-green-500', 'dark:bg-yellow-600', 'dark:bg-green-600')
      this.progressFillTarget.classList.add('bg-red-500', 'dark:bg-red-600')
    } else if (progressPercentage < 70) {
      this.progressFillTarget.classList.remove('bg-red-500', 'bg-green-500', 'dark:bg-red-600', 'dark:bg-green-600')
      this.progressFillTarget.classList.add('bg-yellow-500', 'dark:bg-yellow-600')
    } else {
      this.progressFillTarget.classList.remove('bg-red-500', 'bg-yellow-500', 'dark:bg-red-600', 'dark:bg-yellow-600')
      this.progressFillTarget.classList.add('bg-green-500', 'dark:bg-green-600')
    }
  }

  // Save as draft
  saveDraft(event) {
    if (!this.hasDraftFieldTarget) return
    
    event.preventDefault()
    this.draftFieldTarget.value = true
    
    // Submit the form
    document.getElementById('source-form').submit()
  }
}