// app/javascript/controllers/ace_editor_controller.js
import { Controller } from "@hotwired/stimulus"
import ace from "ace-builds"

// Import common modes and themes
import "ace-builds/mode-ruby"
import "ace-builds/mode-javascript"
import "ace-builds/mode-html"
import "ace-builds/mode-css"
import "ace-builds/theme-monokai"
import "ace-builds/theme-github"

export default class extends Controller {
  static targets = ["editor", "input"]
  static values = {
    mode: { type: String, default: "ruby" },
    theme: { type: String, default: "monokai" },
    fontSize: { type: Number, default: 14 }
  }
  
  editor = null
  
  connect() {
    if (!this.hasEditorTarget) return
    
    this.editor = ace.edit(this.editorTarget)
    this.editor.setTheme(`ace/theme/${this.themeValue}`)
    this.editor.session.setMode(`ace/mode/${this.modeValue}`)
    this.editor.setFontSize(this.fontSizeValue)
    this.editor.setShowPrintMargin(false)
    
    this.editor.setOptions({
      enableBasicAutocompletion: true,
      enableLiveAutocompletion: true,
      wrap: true
    })
    
    // If an input field is connected, update it when the editor changes
    if (this.hasInputTarget) {
      // Set initial editor content from input if available
      if (this.inputTarget.value) {
        this.editor.setValue(this.inputTarget.value, -1) // -1 moves cursor to start
      }
      
      // Update input when editor changes
      this.editor.getSession().on("change", () => {
        this.inputTarget.value = this.editor.getSession().getValue()
      })
    }
  }
  
  disconnect() {
    if (this.editor) {
      this.editor.destroy()
      this.editor = null
    }
  }
  
  changeTheme(event) {
    const theme = event.params.theme || event.target.dataset.theme
    if (this.editor && theme) {
      this.editor.setTheme(`ace/theme/${theme}`)
      this.themeValue = theme
    }
  }
  
  changeMode(event) {
    const mode = event.params.mode || event.target.dataset.mode
    if (this.editor && mode) {
      this.editor.session.setMode(`ace/mode/${mode}`)
      this.modeValue = mode
    }
  }
  
  changeFontSize(event) {
    const size = parseInt(event.params.size || event.target.dataset.size, 10)
    if (this.editor && !isNaN(size)) {
      this.editor.setFontSize(size)
      this.fontSizeValue = size
    }
  }
}