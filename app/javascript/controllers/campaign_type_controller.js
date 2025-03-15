import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["campaignType", "distributionMethod", "biddingOptions", "directOptions", "callsOptions", "typeSpecificSection"]

  connect() {
    this.updateCampaignTypeOptions()
  }

  updateCampaignType() {
    this.updateCampaignTypeOptions()
    this.toggleTypeSpecificSections()
  }
  
  // Handle campaign type-specific sections and options
  updateCampaignTypeOptions() {
    if (!this.hasCampaignTypeTarget || !this.hasDistributionMethodTarget) return
    
    const campaignType = this.campaignTypeTarget.value
    const distributionMethodSelect = this.distributionMethodTarget
    
    // Define allowed distribution methods for each campaign type
    const allowedMethods = {
      'ping_post': ['highest_bid', 'weighted_random', 'waterfall', 'round_robin'],
      'direct': ['round_robin', 'weighted_random', 'waterfall'],
      'calls': ['round_robin', 'weighted_random']
    }
    
    const allowedForType = allowedMethods[campaignType] || []
    
    // Save current value if possible
    const currentValue = distributionMethodSelect.value
    
    // Clear existing options except the blank one
    while (distributionMethodSelect.options.length > 1) {
      distributionMethodSelect.remove(1)
    }
    
    // Add allowed options
    allowedForType.forEach(method => {
      const option = document.createElement('option')
      option.value = method
      option.text = method.replace(/_/g, ' ').replace(/\b\w/g, l => l.toUpperCase())
      distributionMethodSelect.add(option)
    })
    
    // Try to restore the previous value if it's still allowed
    if (allowedForType.includes(currentValue)) {
      distributionMethodSelect.value = currentValue
    } else {
      distributionMethodSelect.selectedIndex = 0 // Select the blank option
    }
    
    // Trigger change event to update dependent UI
    distributionMethodSelect.dispatchEvent(new Event('change'))
    
    // Toggle visibility of type-specific sections
    this.toggleTypeSpecificSections()
  }
  
  toggleTypeSpecificSections() {
    if (!this.hasCampaignTypeTarget) return
    
    const campaignType = this.campaignTypeTarget.value
    
    // Hide all type-specific sections
    if (this.hasTypeSpecificSectionTarget) {
      this.typeSpecificSectionTargets.forEach(section => {
        section.classList.add('hidden')
      })
    }
    
    // Show bidding options for ping-post with bidding
    if (this.hasBiddingOptionsTarget) {
      if (campaignType === 'ping_post' && this.isUsingBidding()) {
        this.biddingOptionsTarget.classList.remove('hidden')
      } else {
        this.biddingOptionsTarget.classList.add('hidden')
      }
    }
    
    // Show direct post options
    if (this.hasDirectOptionsTarget) {
      if (campaignType === 'direct') {
        this.directOptionsTarget.classList.remove('hidden')
      } else {
        this.directOptionsTarget.classList.add('hidden')
      }
    }
    
    // Show calls options
    if (this.hasCallsOptionsTarget) {
      if (campaignType === 'calls') {
        this.callsOptionsTarget.classList.remove('hidden')
      } else {
        this.callsOptionsTarget.classList.add('hidden')
      }
    }
  }
  
  // Handle distribution method changes
  updateDistributionMethod() {
    this.toggleTypeSpecificSections()
  }
  
  // Helper to check if using bidding (ping-post with bidding method)
  isUsingBidding() {
    if (!this.hasDistributionMethodTarget) return false
    
    const biddingMethods = ['highest_bid', 'weighted_random', 'waterfall']
    return this.distributionMethodTarget.value && biddingMethods.includes(this.distributionMethodTarget.value)
  }
}