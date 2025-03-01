import { Controller } from "@hotwired/stimulus"
import Sortable from "sortablejs";

export default class extends Controller {
  static values = {
    resourceUrl: String
  }

  connect() {
    this.sortable = Sortable.create(this.element.querySelector('#sortable-fields'), {
      handle: '.handle',
      animation: 150,
      onEnd: this.onDragEnd.bind(this)
    });
  }

  onDragEnd(event) {
    const itemId = event.item.dataset.id;
    const newPosition = event.newIndex + 1; // Position is 1-based in our backend
    
    if (itemId && this.resourceUrlValue) {
      // Construct the URL for the specific item
      const url = `${this.resourceUrlValue}/${itemId}/move`;
      
      // Send the update request
      fetch(url, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'X-CSRF-Token': document.querySelector("meta[name='csrf-token']").content
        },
        body: JSON.stringify({ position: newPosition })
      }).catch(error => {
        console.error('Error updating position:', error);
      });
    }
  }
}