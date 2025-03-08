import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["ruleType", "conditionSection", "parametersSection"]
  
  connect() {
    this.updateFormSections()
  }
  
  changeRuleType() {
    this.updateFormSections()
  }
  
  updateFormSections() {
    const ruleType = this.ruleTypeTarget.value
    
    switch (ruleType) {
      case "condition":
        this.showSection(this.conditionSectionTarget)
        this.hideSection(this.parametersSectionTarget)
        break
        
      case "pattern":
        this.updatePatternParameters()
        this.hideSection(this.conditionSectionTarget)
        this.showSection(this.parametersSectionTarget)
        break
        
      case "lookup":
        this.updateLookupParameters()
        this.hideSection(this.conditionSectionTarget)
        this.showSection(this.parametersSectionTarget)
        break
        
      case "dependency":
        this.updateDependencyParameters()
        this.hideSection(this.conditionSectionTarget)
        this.showSection(this.parametersSectionTarget)
        break
        
      case "comparison":
        this.updateComparisonParameters()
        this.hideSection(this.conditionSectionTarget)
        this.showSection(this.parametersSectionTarget)
        break
        
      case "custom":
        this.showSection(this.conditionSectionTarget)
        this.hideSection(this.parametersSectionTarget)
        break
        
      default:
        this.showSection(this.conditionSectionTarget)
        this.showSection(this.parametersSectionTarget)
    }
  }
  
  showSection(element) {
    element.classList.remove('hidden')
  }
  
  hideSection(element) {
    element.classList.add('hidden')
  }
  
  updatePatternParameters() {
    const parametersElement = this.parametersSectionTarget.querySelector('textarea')
    let parameters = {}
    
    try {
      parameters = JSON.parse(parametersElement.value)
    } catch (e) {
      // Initialize with empty object if not valid JSON
      parameters = {}
    }
    
    if (!parameters.field_name) {
      parameters.field_name = ""
    }
    
    if (!parameters.pattern) {
      parameters.pattern = ""
    }
    
    parametersElement.value = JSON.stringify(parameters, null, 2)
  }
  
  updateLookupParameters() {
    const parametersElement = this.parametersSectionTarget.querySelector('textarea')
    let parameters = {}
    
    try {
      parameters = JSON.parse(parametersElement.value)
    } catch (e) {
      // Initialize with empty object if not valid JSON
      parameters = {}
    }
    
    if (!parameters.field_name) {
      parameters.field_name = ""
    }
    
    if (!parameters.lookup_values || !Array.isArray(parameters.lookup_values)) {
      parameters.lookup_values = []
    }
    
    parametersElement.value = JSON.stringify(parameters, null, 2)
  }
  
  updateDependencyParameters() {
    const parametersElement = this.parametersSectionTarget.querySelector('textarea')
    let parameters = {}
    
    try {
      parameters = JSON.parse(parametersElement.value)
    } catch (e) {
      // Initialize with empty object if not valid JSON
      parameters = {}
    }
    
    if (!parameters.primary_field) {
      parameters.primary_field = ""
    }
    
    if (!parameters.dependent_field) {
      parameters.dependent_field = ""
    }
    
    parametersElement.value = JSON.stringify(parameters, null, 2)
  }
  
  updateComparisonParameters() {
    const parametersElement = this.parametersSectionTarget.querySelector('textarea')
    let parameters = {}
    
    try {
      parameters = JSON.parse(parametersElement.value)
    } catch (e) {
      // Initialize with empty object if not valid JSON
      parameters = {}
    }
    
    if (!parameters.field_name) {
      parameters.field_name = ""
    }
    
    if (!parameters.operator) {
      parameters.operator = "=="
    }
    
    // Initialize either comparison_field or comparison_value
    if (!parameters.comparison_field && !parameters.comparison_value) {
      parameters.comparison_value = ""
    }
    
    parametersElement.value = JSON.stringify(parameters, null, 2)
  }
}