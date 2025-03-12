import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["dataType", "valueAcceptance", "rangeSection", "textSection", "listSection"]

  connect() {
    this.updateFieldType()
    this.updateValueAcceptance()
  }

  updateFieldType() {
    // Get the selected data type
    const dataType = this.dataTypeTarget.value
    
    // Hide all type-specific sections
    this.hideAllSections()
    
    // Show relevant sections based on data type
    if (dataType === "text" || dataType === "email" || dataType === "phone") {
      this.textSectionTarget.classList.remove("hidden")
    } else if (dataType === "number") {
      this.rangeSectionTarget.classList.remove("hidden")
    }
    
    // Update value acceptance options based on data type
    this.updateValueAcceptanceOptions(dataType)
  }
  
  updateValueAcceptance() {
    const valueAcceptance = this.valueAcceptanceTarget.value
    
    // Show or hide list section
    if (valueAcceptance === "list") {
      this.listSectionTarget.classList.remove("hidden")
    } else {
      this.listSectionTarget.classList.add("hidden")
    }
    
    // Show or hide range section for number fields with range acceptance
    const dataType = this.dataTypeTarget.value
    if (dataType === "number" && valueAcceptance === "range") {
      this.rangeSectionTarget.classList.remove("hidden")
    }
  }
  
  hideAllSections() {
    // Hide all type-specific sections
    this.textSectionTarget.classList.add("hidden")
    this.rangeSectionTarget.classList.add("hidden")
    this.listSectionTarget.classList.add("hidden")
  }
  
  updateValueAcceptanceOptions(dataType) {
    // Enable/disable value acceptance options based on data type
    const valueAcceptanceSelect = this.valueAcceptanceTarget
    
    // Store current value
    const currentValue = valueAcceptanceSelect.value
    
    // Clear all options
    valueAcceptanceSelect.innerHTML = ""
    
    // Apply dark mode styling if needed
    if (document.documentElement.classList.contains('dark')) {
      valueAcceptanceSelect.classList.add('dark:border-gray-700', 'dark:bg-gray-800', 'dark:text-white')
    }
    
    // Add "Any" option for all types
    const anyOption = document.createElement("option")
    anyOption.value = "any"
    anyOption.text = "Any"
    valueAcceptanceSelect.add(anyOption)
    
    // Add "List" option for text, number, boolean
    if (["text", "number", "boolean"].includes(dataType)) {
      const listOption = document.createElement("option")
      listOption.value = "list"
      listOption.text = "List"
      valueAcceptanceSelect.add(listOption)
    }
    
    // Add "Range" option for number only
    if (dataType === "number") {
      const rangeOption = document.createElement("option")
      rangeOption.value = "range"
      rangeOption.text = "Range"
      valueAcceptanceSelect.add(rangeOption)
    }
    
    // Try to restore previous value if it's still valid
    for (let i = 0; i < valueAcceptanceSelect.options.length; i++) {
      if (valueAcceptanceSelect.options[i].value === currentValue) {
        valueAcceptanceSelect.selectedIndex = i
        return
      }
    }
    
    // Default to "Any" if previous value is no longer valid
    valueAcceptanceSelect.selectedIndex = 0
  }
}