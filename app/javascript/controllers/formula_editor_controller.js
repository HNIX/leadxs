import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["fields", "formulaInput", "documentation"]
  static values = {
    campaignId: Number,
    darkMode: Boolean
  }

  connect() {
    console.log("Formula editor controller connected");
    if (this.hasFieldsTarget && this.hasFormulaInputTarget) {
      this.fieldsTarget.addEventListener('change', this.insertField.bind(this));
    }
  }

  disconnect() {
    if (this.hasFieldsTarget) {
      this.fieldsTarget.removeEventListener('change', this.insertField.bind(this));
    }
  }

  insertField() {
    if (!this.hasFieldsTarget || !this.hasFormulaInputTarget) return;
    
    const selectedField = this.fieldsTarget.value;
    if (!selectedField) return;
    
    // Get current cursor position
    const startPos = this.formulaInputTarget.selectionStart;
    const endPos = this.formulaInputTarget.selectionEnd;
    
    // Current value
    const currentText = this.formulaInputTarget.value;
    
    // Insert field reference at cursor position
    const fieldReference = `field('${selectedField}')`;
    const newText = currentText.substring(0, startPos) + fieldReference + currentText.substring(endPos);
    
    // Update textarea value
    this.formulaInputTarget.value = newText;
    
    // Reset dropdown
    this.fieldsTarget.selectedIndex = 0;
    
    // Focus back on textarea and place cursor after inserted field
    this.formulaInputTarget.focus();
    const newCursorPos = startPos + fieldReference.length;
    this.formulaInputTarget.setSelectionRange(newCursorPos, newCursorPos);
  }

  toggleDocumentation() {
    if (this.hasDocumentationTarget) {
      this.documentationTarget.classList.toggle('hidden');
    }
  }
}