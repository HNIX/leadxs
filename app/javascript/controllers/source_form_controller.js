import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["payoutMethodSelect", "payoutGroup", "marginGroup"]

  connect() {
    // Set initial state based on selected value
    this.toggleFields()
  }

  toggleFields() {
    const selectedMethod = this.payoutMethodSelectTarget.value
    
    if (selectedMethod === "percentage") {
      this.marginGroupTarget.classList.remove("hidden")
      this.payoutGroupTarget.classList.add("hidden")
    } else if (selectedMethod === "fixed") {
      this.marginGroupTarget.classList.add("hidden")
      this.payoutGroupTarget.classList.remove("hidden")
    } else {
      // If nothing is selected, hide both
      this.marginGroupTarget.classList.add("hidden")
      this.payoutGroupTarget.classList.add("hidden")
    }
  }
}