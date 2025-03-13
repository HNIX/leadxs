import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="form-public"
export default class extends Controller {
  static targets = ["form", "step", "nextButton", "prevButton", "submitButton", "error", "progress"]
  
  // Track time spent on form
  static values = {
    startTime: Number,
    formToken: String,
    sourceId: String,
    redirectUrl: String
  }
  
  connect() {
    this.startTimeValue = Date.now()
    this.fieldStartTimes = {}
    this.fieldDropoffs = {}
    this.currentStep = 0
    this.totalSteps = this.hasStepTargets ? this.stepTargets.length : 1
    
    // Initialize multi-step form if needed
    if (this.hasStepTargets && this.stepTargets.length > 1) {
      this._showCurrentStep()
      this._updateProgress()
    }
    
    // Track when user starts filling out the form
    this.formTarget.addEventListener('focusin', this._trackFormStart.bind(this), { once: true })
    
    // Track time on individual fields
    const inputs = this.formTarget.querySelectorAll('input, select, textarea')
    inputs.forEach(input => {
      input.addEventListener('focus', () => this._fieldFocused(input))
      input.addEventListener('blur', () => this._fieldBlurred(input))
    })
  }
  
  // Submit form
  submitForm(event) {
    event.preventDefault()
    
    // Validate form
    if (!this.formTarget.checkValidity()) {
      this.formTarget.reportValidity()
      return
    }
    
    // Disable submit button to prevent double submission
    if (this.hasSubmitButtonTarget) {
      this.submitButtonTarget.disabled = true
    }
    
    // Get form data
    const formData = new FormData(this.formTarget)
    const formDataObj = {}
    
    // Convert FormData to object for submission with field name mapping
    for (const [elementId, value] of formData.entries()) {
      // Check if this element has a field name data attribute
      const element = this.formTarget.querySelector(`[name="${elementId}"]`);
      if (element && element.dataset.fieldName) {
        // Use the field name instead of the element ID
        formDataObj[element.dataset.fieldName] = value;
        // Also add with the original element ID as fallback
        formDataObj[elementId] = value;
        // Log for debugging
        console.log(`Mapping form field: ${elementId} -> ${element.dataset.fieldName} = ${value}`);
      } else {
        formDataObj[elementId] = value;
        console.log(`Standard form field: ${elementId} = ${value}`);
      }
    }
    
    // Explicitly add first_name and last_name if they exist in the form
    const firstNameInput = this.formTarget.querySelector('[data-field-name="first_name"]');
    if (firstNameInput) {
      formDataObj["first_name"] = firstNameInput.value;
      console.log(`Explicitly added first_name = ${firstNameInput.value}`);
    }
    
    const lastNameInput = this.formTarget.querySelector('[data-field-name="last_name"]');
    if (lastNameInput) {
      formDataObj["last_name"] = lastNameInput.value;
      console.log(`Explicitly added last_name = ${lastNameInput.value}`);
    }
    
    // Get consent text if present
    const consentElement = this.formTarget.querySelector('[data-consent]')
    const consentText = consentElement ? consentElement.textContent.trim() : null
    
    // Get time tracking data
    const timeData = {
      total_time: Math.floor((Date.now() - this.startTimeValue) / 1000),
      field_dropoffs: this.fieldDropoffs
    }
    
    // Get device info
    const deviceInfo = {
      screen_width: window.screen.width,
      screen_height: window.screen.height,
      user_agent: navigator.userAgent,
      device_type: this._getDeviceType()
    }
    
    // Build submission payload
    const payload = {
      form_data: formDataObj,
      consent_text: consentText,
      time_data: timeData,
      device_info: deviceInfo
    }
    
    // Add source_id if available - ensure it's a clean value without quotes
    if (this.sourceIdValue) {
      // Convert to a number if it's a numeric string
      const sourceId = /^\d+$/.test(this.sourceIdValue) ? parseInt(this.sourceIdValue, 10) : this.sourceIdValue;
      console.log("Sending source ID:", sourceId, "type:", typeof sourceId);
      payload.source_id = sourceId;
    }
    
    // Submit form data
    fetch(`/f/${this.formTokenValue}/submit`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json'
      },
      body: JSON.stringify(payload)
    })
    .then(response => response.json())
    .then(data => {
      if (data.success) {
        // Redirect to success page or custom redirect URL
        window.location.href = this.redirectUrlValue || data.redirect_url
      } else {
        // Show error
        this._showError(data.errors ? data.errors.join(', ') : 'An error occurred')
        
        // Re-enable submit button
        if (this.hasSubmitButtonTarget) {
          this.submitButtonTarget.disabled = false
        }
      }
    })
    .catch(error => {
      this._showError('An error occurred while submitting the form')
      console.error('Form submission error:', error)
      
      // Re-enable submit button
      if (this.hasSubmitButtonTarget) {
        this.submitButtonTarget.disabled = false
      }
    })
  }
  
  // Go to next step in multi-step form
  nextStep() {
    if (!this._validateCurrentStep()) {
      return
    }
    
    if (this.currentStep < this.totalSteps - 1) {
      this.currentStep++
      this._showCurrentStep()
      this._updateProgress()
    }
  }
  
  // Go to previous step in multi-step form
  prevStep() {
    if (this.currentStep > 0) {
      this.currentStep--
      this._showCurrentStep()
      this._updateProgress()
    }
  }
  
  // Show current step and hide others
  _showCurrentStep() {
    this.stepTargets.forEach((step, index) => {
      step.classList.toggle('hidden', index !== this.currentStep)
    })
    
    // Update button visibility
    if (this.hasPrevButtonTarget) {
      this.prevButtonTarget.classList.toggle('hidden', this.currentStep === 0)
    }
    
    if (this.hasNextButtonTarget) {
      this.nextButtonTarget.classList.toggle('hidden', this.currentStep === this.totalSteps - 1)
    }
    
    if (this.hasSubmitButtonTarget) {
      this.submitButtonTarget.classList.toggle('hidden', this.currentStep !== this.totalSteps - 1)
    }
    
    // Update iframe height for responsive sizing
    this._resizeIframe()
  }
  
  // Update progress indicator
  _updateProgress() {
    if (this.hasProgressTarget) {
      const percent = (this.currentStep / (this.totalSteps - 1)) * 100
      this.progressTarget.style.width = `${percent}%`
      this.progressTarget.setAttribute('aria-valuenow', percent)
    }
  }
  
  // Validate current step
  _validateCurrentStep() {
    if (!this.hasStepTargets) return true
    
    const currentStepElement = this.stepTargets[this.currentStep]
    const inputs = currentStepElement.querySelectorAll('input, select, textarea')
    
    let isValid = true
    
    inputs.forEach(input => {
      if (input.hasAttribute('required') && !input.checkValidity()) {
        input.reportValidity()
        isValid = false
      }
    })
    
    return isValid
  }
  
  // Show error message
  _showError(message) {
    if (this.hasErrorTarget) {
      this.errorTarget.textContent = message
      this.errorTarget.classList.remove('hidden')
      
      // Scroll to error
      this.errorTarget.scrollIntoView({ behavior: 'smooth' })
    }
  }
  
  // Track when form is started
  _trackFormStart() {
    // Send analytics event to track form start
    const analytics = this.formTarget.querySelector('[data-analytics]')
    if (analytics) {
      const date = new Date().toISOString().split('T')[0]
      const url = `/api/form_analytics/${this.formTokenValue}/track_start?date=${date}`
      
      fetch(url, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json'
        }
      }).catch(err => console.error('Error tracking form start:', err))
    }
  }
  
  // Track when field is focused
  _fieldFocused(input) {
    const fieldId = input.id || input.name
    this.fieldStartTimes[fieldId] = Date.now()
  }
  
  // Track when field is blurred (left)
  _fieldBlurred(input) {
    const fieldId = input.id || input.name
    
    if (this.fieldStartTimes[fieldId]) {
      const timeSpent = Math.floor((Date.now() - this.fieldStartTimes[fieldId]) / 1000)
      
      // If field was not filled out, increment dropoff counter
      if (!input.value && timeSpent > 2) {
        this.fieldDropoffs[fieldId] = (this.fieldDropoffs[fieldId] || 0) + 1
      }
      
      delete this.fieldStartTimes[fieldId]
    }
  }
  
  // Get device type based on screen size
  _getDeviceType() {
    const width = window.innerWidth
    
    if (width <= 640) {
      return 'mobile'
    } else if (width <= 1024) {
      return 'tablet'
    } else {
      return 'desktop'
    }
  }
  
  // Resize iframe to fit content
  _resizeIframe() {
    // This helps the parent page resize the iframe to fit the content
    const height = document.body.scrollHeight
    
    if (window.parent && window.parent !== window) {
      window.parent.postMessage({
        type: 'swaped-form-resize',
        height: height
      }, '*')
    }
  }
}