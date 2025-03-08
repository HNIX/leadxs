import { Controller } from "@hotwired/stimulus"

import "ace/ace";
import "ace/theme-monokai"
import "ace/mode-javascript";

export default class extends Controller {
  static targets = ["editor", "input"]
  static values = { workerJavascriptUrl: String, doc: String }

  connect() {
    // manually set the module URL for the javascript worker
    ace.config.setModuleUrl("ace/mode/javascript_worker", this.workerJavascriptUrlValue);
    
    // initialize ace editor
    this.editor = ace.edit("ace-editor");
    this.editor.setTheme("ace/theme/monokai");
    this.editor.session.setMode("ace/mode/javascript");
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

}