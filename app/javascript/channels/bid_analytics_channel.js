import consumer from "./consumer"

// Only create the subscription if we're on a relevant page
const isRelevantPage = document.querySelector('[data-channel="bid-analytics"]')

const channel = isRelevantPage ? 
  consumer.subscriptions.create("BidAnalyticsChannel", {
  connected() {
    console.log("Connected to BidAnalyticsChannel")
  },

  disconnected() {
    console.log("Disconnected from BidAnalyticsChannel")
  },

  received(data) {
    console.log("Received data:", data)
    
    // Update dashboard elements based on the data received
    if (data.type === 'snapshot_update') {
      updateDashboardMetrics(data.metrics)
    } else if (data.type === 'new_bid') {
      updateRealtimeBidCounter(data.bid)
    }
  }
}) : null

// Only define these functions if we're on a relevant page
if (isRelevantPage) {
  // Function to update dashboard metrics
function updateDashboardMetrics(metrics) {
  Object.keys(metrics).forEach(key => {
    const element = document.getElementById(`metric-${key}`)
    if (element) {
      element.textContent = metrics[key]
    }
  })
  
  // Update charts if they exist
  if (window.bidVolumeChart) {
    updateBidVolumeChart(metrics.bidVolumes)
  }
  
  if (window.conversionRateChart) {
    updateConversionRateChart(metrics.conversionRates)
  }
}

// Function to update realtime bid counter
function updateRealtimeBidCounter(bid) {
  // Update the counter
  const counterElement = document.getElementById('realtime-bid-counter')
  if (counterElement) {
    const currentCount = parseInt(counterElement.textContent || '0')
    counterElement.textContent = currentCount + 1
  }
  
  // Add bid to the live feed
  const feedElement = document.getElementById('bid-live-feed')
  if (feedElement) {
    const bidItem = document.createElement('div')
    bidItem.classList.add('bid-item', bid.status)
    bidItem.innerHTML = `
      <span class="time">${new Date().toLocaleTimeString()}</span>
      <span class="amount">$${bid.amount.toFixed(2)}</span>
      <span class="status">${bid.status}</span>
      <span class="campaign">${bid.campaign}</span>
    `
    feedElement.prepend(bidItem)
    
    // Limit feed to 20 items
    const items = feedElement.querySelectorAll('.bid-item')
    if (items.length > 20) {
      feedElement.removeChild(items[items.length - 1])
    }
  }
}
} // Close the if (isRelevantPage) block