// app/javascript/ace_editor_setup.js
import ace from "ace-builds";
import "ace-builds/mode-ruby";
import "ace-builds/mode-javascript";
import "ace-builds/mode-html";
import "ace-builds/mode-css";
import "ace-builds/theme-monokai";
import "ace-builds/theme-github";

// Export function to initialize Ace
export function initAceEditor(elementId, options = {}) {
  // Default options
  const defaultOptions = {
    mode: "ace/mode/ruby",
    theme: "ace/theme/monokai",
    fontSize: 14,
    showPrintMargin: false,
    highlightActiveLine: true,
    enableBasicAutocompletion: true,
    enableLiveAutocompletion: true,
    wrap: true
  };
  
  // Merge provided options with defaults
  const editorOptions = {...defaultOptions, ...options};
  
  // Create editor instance
  const editor = ace.edit(elementId);
  
  // Apply options
  editor.setTheme(editorOptions.theme);
  editor.session.setMode(editorOptions.mode);
  editor.setFontSize(editorOptions.fontSize);
  editor.setShowPrintMargin(editorOptions.showPrintMargin);
  editor.setHighlightActiveLine(editorOptions.highlightActiveLine);
  editor.setOptions({
    enableBasicAutocompletion: editorOptions.enableBasicAutocompletion,
    enableLiveAutocompletion: editorOptions.enableLiveAutocompletion,
    wrap: editorOptions.wrap
  });
  
  // If connected to a form, update the hidden field on change
  const hiddenField = document.getElementById(`${elementId}-content`);
  if (hiddenField) {
    editor.getSession().on("change", function() {
      hiddenField.value = editor.getSession().getValue();
    });
  }
  
  return editor;
}