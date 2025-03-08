import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["testData", "results", "valid", "invalid", "errorMessage"]
  
  connect() {
    // Initialize controller
  }
  
  testRule(event) {
    event.preventDefault()
    
    // Get the test data
    let testData
    try {
      testData = JSON.parse(this.testDataTarget.value)
    } catch (error) {
      this.showError("Invalid JSON data: " + error.message)
      return
    }
    
    // Get the rule details from the form
    const form = event.target.closest('form')
    
    const ruleType = form.querySelector('#validation_rule_rule_type').value
    const name = form.querySelector('#validation_rule_name').value
    const condition = form.querySelector('#validation_rule_condition').value
    const parametersStr = form.querySelector('#validation_rule_parameters').value
    const errorMessage = form.querySelector('#validation_rule_error_message').value
    
    // Get the validation URL
    const validationUrl = this.element.closest('form').action.replace(/\/new$|\/edit$|\/\d+\/edit$/, '') + '/test'
    
    // Prepare the validation rule data
    const validationRule = {
      rule_type: ruleType,
      name: name,
      condition: condition,
      parameters: parametersStr,
      error_message: errorMessage
    }
    
    // Send the test request
    fetch(validationUrl, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'X-CSRF-Token': document.querySelector("meta[name='csrf-token']").content
      },
      body: JSON.stringify({
        test_data: testData,
        validation_rule: validationRule
      })
    })
    .then(response => response.json())
    .then(data => {
      // Show the results
      this.showResults(data)
    })
    .catch(error => {
      this.showError("Error testing rule: " + error.message)
    })
  }
  
  showResults(data) {
    // Show the results section
    this.resultsTarget.classList.remove('hidden')
    
    if (data.valid) {
      // Show valid message
      this.validTarget.classList.remove('hidden')
      this.invalidTarget.classList.add('hidden')
    } else {
      // Show invalid message with error
      this.validTarget.classList.add('hidden')
      this.invalidTarget.classList.remove('hidden')
      this.errorMessageTarget.textContent = data.error_message
    }
  }
  
  showError(message) {
    // Show error message
    this.resultsTarget.classList.remove('hidden')
    this.validTarget.classList.add('hidden')
    this.invalidTarget.classList.remove('hidden')
    this.errorMessageTarget.textContent = message
  }
}