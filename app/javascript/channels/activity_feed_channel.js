import consumer from "./consumer"

document.addEventListener('turbo:load', () => {
  const activityStream = document.getElementById('activity-stream')
  const recentLeads = document.getElementById('recent-leads')
  const recentBids = document.getElementById('recent-bids')
  const recentDistributions = document.getElementById('recent-distributions')

  if (activityStream || recentLeads || recentBids || recentDistributions) {
    consumer.subscriptions.create("ActivityFeedChannel", {
      connected() {
        console.log("Connected to ActivityFeedChannel")
      },

      disconnected() {
        // Called when the subscription has been terminated by the server
      },

      received(data) {
        console.log("Received activity update:", data)
        
        if (data.type === 'activity' && activityStream) {
          // Prepend new activity to the activity stream
          const activityContainer = activityStream.querySelector('.space-y-4')
          if (activityContainer) {
            const tempDiv = document.createElement('div')
            tempDiv.innerHTML = data.html
            
            // Add animation class
            const newActivity = tempDiv.firstElementChild
            newActivity.classList.add('animate-fadeIn')
            
            // Prepend to container and limit the number of items
            activityContainer.prepend(newActivity)
            
            // Limit the number of displayed activities to 20
            const activities = activityContainer.querySelectorAll(':scope > div')
            if (activities.length > 20) {
              activities[activities.length - 1].remove()
            }
          }
        }
        
        if (data.type === 'lead' && recentLeads) {
          // Prepend new lead to recent leads
          const tempDiv = document.createElement('div')
          tempDiv.innerHTML = data.html
          
          // Add animation class
          const newLead = tempDiv.firstElementChild
          newLead.classList.add('animate-fadeIn')
          
          // Prepend to container
          recentLeads.prepend(newLead)
          
          // Remove the last item if there are more than 10
          const leads = recentLeads.querySelectorAll(':scope > a')
          if (leads.length > 10) {
            leads[leads.length - 1].remove()
          }
        }
        
        if (data.type === 'bid') {
          // Function to update bid container
          const updateBidContainer = (container) => {
            if (!container) return;
            
            const tempDiv = document.createElement('div')
            tempDiv.innerHTML = data.html
            
            // Add animation class
            const newBid = tempDiv.firstElementChild
            newBid.classList.add('animate-fadeIn')
            
            // Prepend to container
            container.prepend(newBid)
            
            // Remove the last item if there are more than 10
            const bids = container.querySelectorAll(':scope > div')
            if (bids.length > 10) {
              bids[bids.length - 1].remove()
            }
          };
          
          // Update bid container
          updateBidContainer(recentBids);
        }
        
        if (data.type === 'distribution') {
          // Function to update distribution container
          const updateDistributionContainer = (container) => {
            if (!container) return;
            
            const tempDiv = document.createElement('div')
            tempDiv.innerHTML = data.html
            
            // Add animation class
            const newDistribution = tempDiv.firstElementChild
            newDistribution.classList.add('animate-fadeIn')
            
            // Prepend to container
            container.prepend(newDistribution)
            
            // Remove the last item if there are more than 10
            const distributions = container.querySelectorAll(':scope > div')
            if (distributions.length > 10) {
              distributions[distributions.length - 1].remove()
            }
          };
          
          // Update distribution container
          updateDistributionContainer(recentDistributions);
        }
      }
    })
  }
})