import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["activityStream", "emptyState", "durationFilter"]

  connect() {
    this.addAnimationStyles()
    this.setupPolling()
    
    // Set the duration filter to match the URL parameter if present
    if (this.hasDurationFilterTarget) {
      const urlParams = new URLSearchParams(window.location.search)
      const dateRange = urlParams.get('date_range')
      
      if (dateRange === 'today') {
        this.durationFilterTarget.value = 'day'
      } else if (dateRange === 'hour') {
        this.durationFilterTarget.value = 'hour'
      } else if (dateRange === 'week') {
        this.durationFilterTarget.value = 'week'
      } else if (!dateRange) {
        this.durationFilterTarget.value = 'all'
      }
    }
  }

  disconnect() {
    if (this.pollingTimer) {
      clearTimeout(this.pollingTimer)
    }
  }

  addAnimationStyles() {
    // Add CSS animation to dynamically added items
    if (!document.getElementById('activity-feed-animations')) {
      const style = document.createElement('style')
      style.id = 'activity-feed-animations'
      style.textContent = `
        @keyframes fadeIn {
          from { opacity: 0; transform: translateY(-10px); }
          to { opacity: 1; transform: translateY(0); }
        }
        .animate-fade-in {
          animation: fadeIn 0.5s ease-out forwards;
        }
      `
      document.head.appendChild(style)
    }
  }

  setupPolling() {
    // Poll for updates every minute as a fallback for when WebSockets are not working
    this.pollingTimer = setTimeout(() => {
      this.refreshFeed()
    }, 60000)
  }

  refreshFeed() {
    fetch(window.location.pathname + '.json' + window.location.search)
      .then(response => response.json())
      .then(data => {
        // Handle the data if needed for polling updates
        console.log('Polled for activity feed data:', data)
      })
      .catch(error => {
        console.error('Error fetching activity feed:', error)
      })
      .finally(() => {
        // Schedule the next poll
        this.pollingTimer = setTimeout(() => {
          this.refreshFeed()
        }, 60000)
      })
  }
  
  // Triggered when the user changes the duration filter dropdown
  filter(event) {
    const duration = event.target.value
    const url = new URL(window.location)
    
    // Set the duration as a query parameter
    if (duration === 'all') {
      url.searchParams.delete('date_range')
    } else if (duration === 'hour') {
      url.searchParams.set('date_range', 'hour')
    } else if (duration === 'day') {
      url.searchParams.set('date_range', 'today')
    } else if (duration === 'week') {
      url.searchParams.set('date_range', 'week')
    }
    
    // Navigate to the filtered URL
    window.location = url.toString()
  }
  
  // Triggered when the user clicks the refresh button
  refresh() {
    // Reload the current page to get fresh data
    window.location.reload()
  }
}