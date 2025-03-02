import { Controller } from "@hotwired/stimulus";
import {EditorView, basicSetup} from "codemirror"
//import {javascript} from "@codemirror/lang-javascript"
//import { autocompletion } from "@codemirror/autocomplete"

// import "codemirror/mode/javascript/javascript";
// import "codemirror/addon/hint/show-hint";
// import "codemirror/addon/edit/matchbrackets";
// import "codemirror/addon/edit/closebrackets";

export default class extends Controller {
  static targets = ["editor", "input", "fields", "errors", "documentation"];
  static values = {
    campaignId: String,
    darkMode: Boolean
  }

  connect() {
    this.initializeEditor();
    this.fetchCampaignFields();
    this.setupFieldsDropdown();
  }


  initializeEditor() {
    const theme = this.darkModeValue ? "dracula" : "default";
    
    this.editor = new EditorView(this.inputTarget, {
      mode: "javascript",
      theme: theme,
      lineNumbers: true,
      autoCloseBrackets: true, 
      //matchBrackets: true,
      extraKeys: {
        "Ctrl-Space": this.showHint.bind(this),
        "Tab": function(cm) {
          const spaces = Array(cm.getOption("indentUnit") + 1).join(" ");
          cm.replaceSelection(spaces);
        }
      }
     });

    // Initialize with existing value
    if (this.inputTarget.value) {
      this.editor.setValue(this.inputTarget.value);
    }

    // Update hidden input when editor changes
    this.editor.on("change", () => {
      this.inputTarget.value = this.editor.getValue();
      //this.validateFormula();
    });

    // Initial validation
    //this.validateFormula();
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
    const cursor = this.editor.getCursor();
    this.editor.replaceRange(`field('${fieldName}')`, cursor);
    this.editor.focus();
  }

  fetchCampaignFields() {
    fetch(`/campaigns/${this.campaignIdValue}/fields.json`)
      .then(response => response.json())
      .then(data => {
        this.campaignFields = data;
        this.updateFieldsDropdown();
      })
      .catch(error => console.error("Error fetching campaign fields:", error));
  }

  updateFieldsDropdown() {
    // Clear current options (except the default one)
    const dropdown = this.fieldsTarget;
    while (dropdown.options.length > 1) {
      dropdown.remove(1);
    }

    // Add field options grouped by data type
    if (this.campaignFields) {
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
    }
  }

  showHint() {
    this.editor.showHint({
      hint: this.createHintFunction(),
      completeSingle: false
    });
  }

  createHintFunction() {
    const functions = [
      { text: "field('fieldName')", displayText: "field()" },
      { text: "concat(a, b)", displayText: "concat()" },
      { text: "toString(value)", displayText: "toString()" },
      { text: "toNumber(value)", displayText: "toNumber()" },
      { text: "toDate(value)", displayText: "toDate()" },
      { text: "formatDate(date, format)", displayText: "formatDate()" },
      { text: "now()", displayText: "now()" },
      { text: "today()", displayText: "today()" },
      { text: "if(condition, trueValue, falseValue)", displayText: "if()" },
      { text: "add(a, b)", displayText: "add()" },
      { text: "subtract(a, b)", displayText: "subtract()" },
      { text: "multiply(a, b)", displayText: "multiply()" },
      { text: "divide(a, b)", displayText: "divide()" },
      { text: "round(value, decimals)", displayText: "round()" },
      { text: "uppercase(text)", displayText: "uppercase()" },
      { text: "lowercase(text)", displayText: "lowercase()" },
      { text: "trim(text)", displayText: "trim()" },
      { text: "length(text)", displayText: "length()" }
    ];

    const fieldOptions = this.campaignFields ? 
      this.campaignFields.map(field => ({ 
        text: `field('${field.name}')`, 
        displayText: `field('${field.name}')` 
      })) : [];

    return (cm) => {
      const cursor = cm.getCursor();
      const line = cm.getLine(cursor.line);
      const start = cursor.ch;
      const end = start;

      return {
        list: [...functions, ...fieldOptions],
        from: CM.Pos(cursor.line, start),
        to: CM.Pos(cursor.line, end)
      };
    };
  }

  // validateFormula() {
  //   const formula = this.editor.getValue();
    
  //   // Skip validation if empty
  //   if (!formula.trim()) {
  //     this.clearErrors();
  //     return;
  //   }

  //   fetch(`/campaigns/${this.campaignIdValue}/calculated_fields/validate`, {
  //     method: 'POST',
  //     headers: {
  //       'Content-Type': 'application/json',
  //       'X-CSRF-Token': document.querySelector('meta[name="csrf-token"]').content
  //     },
  //     body: JSON.stringify({ formula })
  //   })
  //   .then(response => response.json())
  //   .then(data => {
  //     if (data.valid) {
  //       this.clearErrors();
  //     } else {
  //       this.showErrors(data.errors);
  //     }
  //   })
  //   .catch(error => {
  //     console.error("Error validating formula:", error);
  //     this.showErrors(["An error occurred during validation"]);
  //   });
  // }

  clearErrors() {
    this.errorsTarget.innerHTML = "";
    this.errorsTarget.classList.add("hidden");
  }

  showErrors(errors) {
    this.errorsTarget.innerHTML = "";
    this.errorsTarget.classList.remove("hidden");
    
    errors.forEach(error => {
      const errorElement = document.createElement("div");
      errorElement.textContent = error;
      errorElement.classList.add("text-red-600", "text-sm", "mt-1");
      this.errorsTarget.appendChild(errorElement);
    });
  }

  toggleDocumentation() {
    this.documentationTarget.classList.toggle("hidden");
  }
}
