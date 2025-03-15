import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [
    "responseMapping", 
    "container", 
    "statusCodes", 
    "fieldCriteria",
    "errorFields",
    "testResponse",
    "testResult",
    "addStatusButton",
    "addFieldButton",
    "addErrorButton"
  ]
  
  connect() {
    this.updateFormFromJSON()
  }
  
  updateFormFromJSON() {
    const mapping = this.getResponseMapping()
    
    // Clear existing fields first
    this.clearFields()
    
    // Status codes
    if (mapping.success_criteria && mapping.success_criteria.status_codes) {
      mapping.success_criteria.status_codes.forEach(range => {
        this.addStatusCodeField(range)
      })
    } else {
      // Add default status code range
      this.addStatusCodeField("200-299")
    }
    
    // Success field criteria
    if (mapping.success_criteria && mapping.success_criteria.fields) {
      mapping.success_criteria.fields.forEach(field => {
        this.addFieldCriterion(field.path, field.value, field.operator || "eq")
      })
    }
    
    // Error fields
    if (mapping.error_fields) {
      mapping.error_fields.forEach(path => {
        this.addErrorField(path)
      })
    }
  }
  
  getResponseMapping() {
    try {
      const value = this.responseMappingTarget.value
      return value ? JSON.parse(value) : { success_criteria: { status_codes: [] }, error_fields: [] }
    } catch (e) {
      console.error("Error parsing response mapping JSON:", e)
      return { success_criteria: { status_codes: [] }, error_fields: [] }
    }
  }
  
  clearFields() {
    // Clear status codes
    if (this.hasStatusCodesTarget) {
      this.statusCodesTarget.innerHTML = ""
    }
    
    // Clear field criteria
    if (this.hasFieldCriteriaTarget) {
      this.fieldCriteriaTarget.innerHTML = ""
    }
    
    // Clear error fields
    if (this.hasErrorFieldsTarget) {
      this.errorFieldsTarget.innerHTML = ""
    }
  }
  
  addStatusCodeField(value = "") {
    const id = Date.now()
    const html = `
      <div class="flex items-center space-x-2 mb-2" data-status-id="${id}">
        <input type="text" value="${value}" placeholder="e.g. 200-299" 
               class="status-range block rounded-md border-gray-300 shadow-sm focus:border-primary-300 focus:ring focus:ring-primary-200 focus:ring-opacity-50 dark:bg-gray-800 dark:border-gray-700 dark:text-white" />
        <button type="button" data-action="click->response-mapping#removeStatus" data-status-id="${id}"
                class="inline-flex items-center p-1 border border-transparent rounded-full text-red-600 hover:bg-red-50 dark:hover:bg-red-900/10">
          <svg xmlns="http://www.w3.org/2000/svg" class="h-5 w-5" viewBox="0 0 20 20" fill="currentColor">
            <path fill-rule="evenodd" d="M10 18a8 8 0 100-16 8 8 0 000 16zM8.707 7.293a1 1 0 00-1.414 1.414L8.586 10l-1.293 1.293a1 1 0 101.414 1.414L10 11.414l1.293 1.293a1 1 0 001.414-1.414L11.414 10l1.293-1.293a1 1 0 00-1.414-1.414L10 8.586 8.707 7.293z" clip-rule="evenodd" />
          </svg>
        </button>
      </div>
    `
    this.statusCodesTarget.insertAdjacentHTML('beforeend', html)
  }
  
  addFieldCriterion(path = "", value = "", operator = "eq") {
    const id = Date.now()
    const html = `
      <div class="grid grid-cols-12 gap-2 mb-3 field-criterion" data-field-id="${id}">
        <div class="col-span-5">
          <input type="text" value="${path}" placeholder="response.status" 
                 class="field-path block w-full rounded-md border-gray-300 shadow-sm focus:border-primary-300 focus:ring focus:ring-primary-200 focus:ring-opacity-50 dark:bg-gray-800 dark:border-gray-700 dark:text-white" />
          <p class="text-xs text-gray-500 dark:text-gray-400 mt-1">JSON path (dot notation)</p>
        </div>
        <div class="col-span-2">
          <select class="field-operator block w-full rounded-md border-gray-300 shadow-sm focus:border-primary-300 focus:ring focus:ring-primary-200 focus:ring-opacity-50 dark:bg-gray-800 dark:border-gray-700 dark:text-white">
            <option value="eq" ${operator === "eq" ? "selected" : ""}>Equals</option>
            <option value="neq" ${operator === "neq" ? "selected" : ""}>Not Equals</option>
            <option value="contains" ${operator === "contains" ? "selected" : ""}>Contains</option>
            <option value="regex" ${operator === "regex" ? "selected" : ""}>Regex Match</option>
          </select>
          <p class="text-xs text-gray-500 dark:text-gray-400 mt-1">Comparison</p>
        </div>
        <div class="col-span-4">
          <input type="text" value="${value}" placeholder="success" 
                 class="field-value block w-full rounded-md border-gray-300 shadow-sm focus:border-primary-300 focus:ring focus:ring-primary-200 focus:ring-opacity-50 dark:bg-gray-800 dark:border-gray-700 dark:text-white" />
          <p class="text-xs text-gray-500 dark:text-gray-400 mt-1">Expected value</p>
        </div>
        <div class="col-span-1 flex items-start pt-2">
          <button type="button" data-action="click->response-mapping#removeField" data-field-id="${id}"
                  class="inline-flex items-center p-1 border border-transparent rounded-full text-red-600 hover:bg-red-50 dark:hover:bg-red-900/10">
            <svg xmlns="http://www.w3.org/2000/svg" class="h-5 w-5" viewBox="0 0 20 20" fill="currentColor">
              <path fill-rule="evenodd" d="M10 18a8 8 0 100-16 8 8 0 000 16zM8.707 7.293a1 1 0 00-1.414 1.414L8.586 10l-1.293 1.293a1 1 0 101.414 1.414L10 11.414l1.293 1.293a1 1 0 001.414-1.414L11.414 10l1.293-1.293a1 1 0 00-1.414-1.414L10 8.586 8.707 7.293z" clip-rule="evenodd" />
            </svg>
          </button>
        </div>
      </div>
    `
    this.fieldCriteriaTarget.insertAdjacentHTML('beforeend', html)
  }
  
  addErrorField(path = "") {
    const id = Date.now()
    const html = `
      <div class="flex items-center space-x-2 mb-2" data-error-id="${id}">
        <input type="text" value="${path}" placeholder="error.message" 
               class="error-path block w-full rounded-md border-gray-300 shadow-sm focus:border-primary-300 focus:ring focus:ring-primary-200 focus:ring-opacity-50 dark:bg-gray-800 dark:border-gray-700 dark:text-white" />
        <button type="button" data-action="click->response-mapping#removeError" data-error-id="${id}"
                class="inline-flex items-center p-1 border border-transparent rounded-full text-red-600 hover:bg-red-50 dark:hover:bg-red-900/10">
          <svg xmlns="http://www.w3.org/2000/svg" class="h-5 w-5" viewBox="0 0 20 20" fill="currentColor">
            <path fill-rule="evenodd" d="M10 18a8 8 0 100-16 8 8 0 000 16zM8.707 7.293a1 1 0 00-1.414 1.414L8.586 10l-1.293 1.293a1 1 0 101.414 1.414L10 11.414l1.293 1.293a1 1 0 001.414-1.414L11.414 10l1.293-1.293a1 1 0 00-1.414-1.414L10 8.586 8.707 7.293z" clip-rule="evenodd" />
          </svg>
        </button>
      </div>
    `
    this.errorFieldsTarget.insertAdjacentHTML('beforeend', html)
  }
  
  removeStatus(event) {
    const id = event.currentTarget.dataset.statusId
    const element = this.statusCodesTarget.querySelector(`[data-status-id="${id}"]`)
    if (element) element.remove()
    this.updateJSONFromForm()
  }
  
  removeField(event) {
    const id = event.currentTarget.dataset.fieldId
    const element = this.fieldCriteriaTarget.querySelector(`[data-field-id="${id}"]`)
    if (element) element.remove()
    this.updateJSONFromForm()
  }
  
  removeError(event) {
    const id = event.currentTarget.dataset.errorId
    const element = this.errorFieldsTarget.querySelector(`[data-error-id="${id}"]`)
    if (element) element.remove()
    this.updateJSONFromForm()
  }
  
  addStatusCode() {
    this.addStatusCodeField()
    this.updateJSONFromForm()
  }
  
  addField() {
    this.addFieldCriterion()
    this.updateJSONFromForm()
  }
  
  addError() {
    this.addErrorField()
    this.updateJSONFromForm()
  }
  
  updateJSONFromForm() {
    const mapping = {
      success_criteria: {
        status_codes: [],
        fields: []
      },
      error_fields: []
    }
    
    // Collect status codes
    if (this.hasStatusCodesTarget) {
      const statusElements = this.statusCodesTarget.querySelectorAll('.status-range')
      statusElements.forEach(el => {
        if (el.value.trim()) {
          mapping.success_criteria.status_codes.push(el.value.trim())
        }
      })
    }
    
    // Collect field criteria
    if (this.hasFieldCriteriaTarget) {
      const fieldElements = this.fieldCriteriaTarget.querySelectorAll('.field-criterion')
      fieldElements.forEach(fieldEl => {
        const path = fieldEl.querySelector('.field-path').value.trim()
        const value = fieldEl.querySelector('.field-value').value.trim()
        const operator = fieldEl.querySelector('.field-operator').value
        
        if (path && value) {
          mapping.success_criteria.fields.push({
            path,
            value,
            operator
          })
        }
      })
    }
    
    // Collect error fields
    if (this.hasErrorFieldsTarget) {
      const errorElements = this.errorFieldsTarget.querySelectorAll('.error-path')
      errorElements.forEach(el => {
        if (el.value.trim()) {
          mapping.error_fields.push(el.value.trim())
        }
      })
    }
    
    // Update the hidden input
    this.responseMappingTarget.value = JSON.stringify(mapping)
  }
  
  testResponseMapping() {
    try {
      // Get the distribution ID from the form action URL
      const formAction = document.querySelector('form').getAttribute('action')
      const distributionIdMatch = formAction.match(/\/distributions\/(\d+)/)
      const distributionId = distributionIdMatch ? distributionIdMatch[1] : null
      
      if (!distributionId) {
        throw new Error("Could not determine distribution ID")
      }
      
      // Update the JSON from form before testing
      this.updateJSONFromForm()
      
      // Get test values
      const testResponse = this.testResponseTarget.value.trim() || "{}"
      const responseCode = 200 // Default to 200
      
      // Show loading state
      this.testResultTarget.innerHTML = `
        <div class="mt-2 p-3 bg-gray-50 border border-gray-200 rounded-md text-gray-700 dark:bg-gray-700/20 dark:border-gray-600 dark:text-gray-300">
          <p class="font-medium flex items-center">
            <svg class="animate-spin -ml-1 mr-3 h-5 w-5 text-primary-500" xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24">
              <circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4"></circle>
              <path class="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"></path>
            </svg>
            Testing response mapping...
          </p>
        </div>
      `
      
      // Call backend to test
      fetch(`/test_connection/${distributionId}/evaluate_response`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'X-CSRF-Token': document.querySelector('meta[name="csrf-token"]').getAttribute('content')
        },
        body: JSON.stringify({
          response_json: testResponse,
          response_code: responseCode,
          response_mapping: JSON.parse(this.responseMappingTarget.value),
          ping_id_field: document.querySelector('input[name="distribution[ping_id_field]"]')?.value
        })
      })
      .then(response => response.json())
      .then(data => {
        if (data.error) {
          throw new Error(data.error)
        }
        
        // Render success or failure
        if (data.success) {
          let pingIdInfo = ''
          if (data.ping_id) {
            pingIdInfo = `<p class="mt-1">Detected Ping ID: <code class="px-1 py-0.5 bg-green-200 dark:bg-green-800 rounded font-mono">${data.ping_id}</code></p>`
          }
          
          this.testResultTarget.innerHTML = `
            <div class="mt-2 p-3 bg-green-50 border border-green-200 rounded-md text-green-800 dark:bg-green-900/20 dark:border-green-800 dark:text-green-200">
              <p class="font-medium">✅ Success! The response would be interpreted as successful.</p>
              ${pingIdInfo}
            </div>
          `
        } else {
          this.testResultTarget.innerHTML = `
            <div class="mt-2 p-3 bg-red-50 border border-red-200 rounded-md text-red-800 dark:bg-red-900/20 dark:border-red-800 dark:text-red-200">
              <p class="font-medium">❌ Failure! The response would be interpreted as an error.</p>
              <p class="mt-1">Error message: ${data.error_message || 'Unknown error'}</p>
            </div>
          `
        }
      })
      .catch(e => {
        this.testResultTarget.innerHTML = `
          <div class="mt-2 p-3 bg-yellow-50 border border-yellow-200 rounded-md text-yellow-800 dark:bg-yellow-900/20 dark:border-yellow-800 dark:text-yellow-200">
            <p class="font-medium">⚠️ Test Error: ${e.message}</p>
            <p class="mt-1">Please ensure your test response is valid JSON.</p>
          </div>
        `
      })
    } catch (e) {
      this.testResultTarget.innerHTML = `
        <div class="mt-2 p-3 bg-yellow-50 border border-yellow-200 rounded-md text-yellow-800 dark:bg-yellow-900/20 dark:border-yellow-800 dark:text-yellow-200">
          <p class="font-medium">⚠️ Test Error: ${e.message}</p>
          <p class="mt-1">Please ensure your test response is valid JSON.</p>
        </div>
      `
    }
  }
}