import { Controller } from "@hotwired/stimulus"
import {basicSetup, EditorView} from "codemirror"
import {autocompletion} from "@codemirror/autocomplete"
import { json } from "@codemirror/lang-json"

//import {StreamLanguage} from "@codemirror/language"
//import {ruby} from "@codemirror/legacy-modes/mode/ruby"

export default class extends Controller {
  static targets = ["editor", "input", "fields", "errors", "documentation"]
  static values = {
    doc: String,
    campaignId: String,
    darkMode: Boolean
  }

  connect() {
    console.log("Formula editor controller connected");
    console.log("Campaign ID:", this.campaignIdValue);
    this.fetchCampaignFields();
  }

  disconnect() {
    this.editor.destroy()
  }

  sync() {
    this.inputTarget.value = this.editor.state.doc.toString()
  }

  completions(context) {
    let word = context.matchBefore(/\w*/)
    if (word.from == word.to && !context.explicit)
      return null

    return {
      from: word.from,
      options: [
        { label: "User", type: "constant", info: "The User model" }
      ]
    }
  }

  setupFieldsDropdown() {
    this.fieldsTarget.addEventListener("change", (e) => {
      const fieldName = e.target.value;
      if (fieldName) {
        this.insertField(fieldName);
        e.target.value = ""; // Reset dropdown
      }
    });
  }

  insertField(fieldName) {
    // Get the current selection or cursor position
    const start = this.textarea.selectionStart;
    const end = this.textarea.selectionEnd;
    const formula = this.textarea.value;
    
    // Insert the field function at the cursor position
    const insertText = `field('${fieldName}')`;
    this.textarea.value = formula.substring(0, start) + insertText + formula.substring(end);
    
    // Update the hidden input
    this.inputTarget.value = this.textarea.value;
    
    // Update syntax highlighting
    this.highlightCode(this.textarea.value, this.highlightLayer);
    
    // Move the cursor after the inserted text
    this.textarea.focus();
    this.textarea.selectionStart = start + insertText.length;
    this.textarea.selectionEnd = start + insertText.length;
  }

  fetchCampaignFields() {
    const campaignId = this.campaignIdValue;
    if (!campaignId) {
      console.error("No campaign ID provided");
      return;
    }
    
    console.log(`Fetching campaign fields for campaign ID: ${campaignId}`);
    
    fetch(`/campaigns/${campaignId}/fields.json`)
      .then(response => {
        console.log("Response status:", response.status);
        if (!response.ok) {
          throw new Error(`Network response was not ok: ${response.status}`);
        }
        return response.json();
      })
      .then(data => {
        console.log("Campaign fields loaded:", data);
        this.campaignFields = data;
        this.updateFieldsDropdown();
      })
      .catch(error => {
        console.error("Error fetching campaign fields:", error);
        const dropdown = this.fieldsTarget;
        const option = document.createElement("option");
        option.value = "";
        option.text = "Error loading fields";
        option.disabled = true;
        dropdown.appendChild(option);
      });
  }

  updateFieldsDropdown() {
    // Clear current options (except the default one)
    const dropdown = this.fieldsTarget;
    while (dropdown.options.length > 1) {
      dropdown.remove(1);
    }

    // Add field options grouped by data type
    if (this.campaignFields && this.campaignFields.length > 0) {
      // Group fields by data type
      const fieldsByType = this.campaignFields.reduce((acc, field) => {
        const type = field.data_type || "other";
        if (!acc[type]) acc[type] = [];
        acc[type].push(field);
        return acc;
      }, {});

      // Add optgroups for each type
      const dataTypes = {
        "text": "Text Fields",
        "number": "Number Fields",
        "date": "Date Fields",
        "email": "Email Fields",
        "phone": "Phone Fields",
        "boolean": "Boolean Fields",
        "other": "Other Fields"
      };

      Object.keys(fieldsByType).forEach(type => {
        const optgroup = document.createElement("optgroup");
        optgroup.label = dataTypes[type] || type.charAt(0).toUpperCase() + type.slice(1);
        
        fieldsByType[type].forEach(field => {
          const option = document.createElement("option");
          option.value = field.name;
          option.text = `${field.name} (${field.data_type || field.field_type})`;
          optgroup.appendChild(option);
        });
        
        dropdown.appendChild(optgroup);
      });
    } else {
      console.warn("No campaign fields found or empty array received");
      const option = document.createElement("option");
      option.value = "";
      option.text = "No fields available";
      option.disabled = true;
      dropdown.appendChild(option);
    }
  }

  toggleDocumentation() {
    this.documentationTarget.classList.toggle("hidden");
  }

}