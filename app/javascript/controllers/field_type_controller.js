import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["dataType", "valueAcceptance", "rangeSection", "textSection", "listSection"]

  connect() {
    this.updateFieldType()
    this.updateValueAcceptance()
    
    // Initialize distribution form sections if they exist
    this.toggleDistributionFields()
  }

  updateFieldType() {
    // Skip if we don't have the dataType target (e.g., on distribution form)
    if (!this.hasDataTypeTarget) return
    
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
    // Skip if we don't have the valueAcceptance target (e.g., on distribution form)
    if (!this.hasValueAcceptanceTarget) return
    
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
    // Skip if we don't have these targets (e.g., on distribution form)
    if (!this.hasTextSectionTarget || !this.hasRangeSectionTarget || !this.hasListSectionTarget) return
    
    // Hide all type-specific sections
    this.textSectionTarget.classList.add("hidden")
    this.rangeSectionTarget.classList.add("hidden")
    this.listSectionTarget.classList.add("hidden")
  }
  
  updateValueAcceptanceOptions(dataType) {
    // Skip if we don't have the valueAcceptance target (e.g., on distribution form)
    if (!this.hasValueAcceptanceTarget) return
    
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
  
  // For distribution form
  toggleFields() {
    this.toggleDistributionFields()
  }
  
  toggleDistributionFields() {
    // Handle authentication method fields
    const authMethodSelect = document.querySelector('select[data-target="auth-method"]')
    if (authMethodSelect) {
      const selectedAuthMethod = authMethodSelect.value
      
      // Hide all auth method fields
      document.querySelectorAll('.auth-method-field').forEach(field => {
        field.classList.add('hidden')
      })
      
      // Show the selected auth method field
      const selectedField = document.querySelector(`.${selectedAuthMethod}-field`)
      if (selectedField) {
        selectedField.classList.remove('hidden')
      }
    }
    
    // Handle endpoint type fields
    const endpointTypeSelect = document.querySelector('select[data-target="endpoint-type"]')
    if (endpointTypeSelect) {
      const selectedEndpointType = endpointTypeSelect.value
      
      // Hide all endpoint type fields
      document.querySelectorAll('.endpoint-type-field').forEach(field => {
        field.classList.add('hidden')
      })
      
      // Show endpoint type specific fields
      if (selectedEndpointType === 'ping_post') {
        document.querySelectorAll('.ping-post-field').forEach(field => {
          field.classList.remove('hidden')
        })
      }
      
      // Update endpoint URL descriptions
      document.querySelectorAll('.endpoint-type-desc').forEach(desc => {
        desc.classList.add('hidden')
      })
      
      const selectedDesc = document.querySelector(`.endpoint-type-desc.${selectedEndpointType}`)
      if (selectedDesc) {
        selectedDesc.classList.remove('hidden')
      }
    }
  }
}