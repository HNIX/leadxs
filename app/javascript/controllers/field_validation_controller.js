import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["select", "range", "list"]

  connect() {
    this.toggle();
  }

  toggle() {
    // Get the selected validation type

    const validationType = this.selectTarget.value;
    
    // Hide all validation-specific elements
    this.hideAll();
    
    // Show elements specific to the selected validation type
    if (validationType === "range") {
      this.showRangeFields();
    } else if (validationType === "list") {
      this.showListFields();
    }
  }
  
  hideAll() {
    this.rangeTargets.forEach(element => {
      element.style.display = "none";
    });
    
    this.listTargets.forEach(element => {
      element.style.display = "none";
    });
  }
  
  showRangeFields() {
    this.rangeTargets.forEach(element => {
      element.style.display = "block";
    });
  }
  
  showListFields() {
    this.listTargets.forEach(element => {
      element.style.display = "block";
    });
  }
}