import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="form-theme"
export default class extends Controller {
  static targets = ["preview", "colorInput", "fontInput", "radiusInput", "spacingInput", "cssInput"]
  
  connect() {
    this._updatePreview()
  }
  
  // Update preview when inputs change
  colorChanged() {
    this._updatePreview()
  }
  
  fontChanged() {
    this._updatePreview()
  }
  
  radiusChanged() {
    this._updatePreview()
  }
  
  spacingChanged() {
    this._updatePreview()
  }
  
  cssChanged() {
    this._updatePreview()
  }
  
  // Update the preview with current theme settings
  _updatePreview() {
    if (!this.hasPreviewTarget) return
    
    const iframe = this.previewTarget
    const doc = iframe.contentDocument || iframe.contentWindow.document
    
    // Get current values
    const primaryColor = this._getInputValue('primary')
    const secondaryColor = this._getInputValue('secondary')
    const backgroundColor = this._getInputValue('background')
    const textColor = this._getInputValue('text')
    const errorColor = this._getInputValue('error')
    const successColor = this._getInputValue('success')
    const fontFamily = this._getInputValue('font')
    const borderRadius = this._getInputValue('radius')
    const spacing = this._getInputValue('spacing')
    const customCss = this._getInputValue('css')
    
    // Create CSS variables
    const css = `
      :root {
        --color-primary: ${primaryColor};
        --color-secondary: ${secondaryColor};
        --color-background: ${backgroundColor};
        --color-text: ${textColor};
        --color-error: ${errorColor};
        --color-success: ${successColor};
        --font-family: ${fontFamily};
        --border-radius: ${borderRadius};
        --spacing: ${this._getSpacingValue(spacing)};
      }
      
      body {
        font-family: var(--font-family);
        background-color: var(--color-background);
        color: var(--color-text);
      }
      
      .form-control, .form-input {
        border-radius: var(--border-radius);
        margin-bottom: var(--spacing);
      }
      
      .btn, button[type="submit"] {
        background-color: var(--color-primary);
        color: white;
        border-radius: var(--border-radius);
        border: none;
        padding: 0.5rem 1rem;
        cursor: pointer;
      }
      
      .btn:hover, button[type="submit"]:hover {
        background-color: var(--color-secondary);
      }
      
      .error-message {
        color: var(--color-error);
      }
      
      .success-message {
        color: var(--color-success);
      }
      
      /* Custom CSS */
      ${customCss}
    `
    
    // Apply CSS to preview
    let style = doc.getElementById('form-theme-style')
    if (!style) {
      style = doc.createElement('style')
      style.id = 'form-theme-style'
      doc.head.appendChild(style)
    }
    
    style.textContent = css
  }
  
  // Get input value based on input type
  _getInputValue(type) {
    const selector = `[data-form-theme-target="${type}Input"]`
    const input = this.element.querySelector(selector)
    return input ? input.value : ''
  }
  
  // Convert spacing value to CSS
  _getSpacingValue(spacing) {
    switch (spacing) {
      case 'compact':
        return '0.5rem'
      case 'comfortable':
        return '1rem'
      case 'spacious':
        return '1.5rem'
      default:
        return '1rem'
    }
  }
}