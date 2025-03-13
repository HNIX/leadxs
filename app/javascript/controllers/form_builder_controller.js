import { Controller } from "@hotwired/stimulus"
import Sortable from "sortablejs"

// Connects to data-controller="form-builder"
export default class extends Controller {
  static targets = ["canvas", "palette", "element", "elementField", "preview"]
  
  connect() {
    console.log("Form builder controller connected")
    this._initSortable()
    this._initDragAndDrop()
  }
  
  disconnect() {
    console.log("Form builder controller disconnected")
    if (this.canvasSortable) {
      this.canvasSortable.destroy()
    }
    
    // Clean up event listeners
    if (this.paletteItems) {
      this.paletteItems.forEach(item => {
        item.removeEventListener("dragstart", this._boundDragStart)
        item.removeEventListener("dragend", this._boundDragEnd)
      })
    }
    
    if (this.hasCanvasTarget) {
      this.canvasTarget.removeEventListener("dragenter", this._boundDragEnter)
      this.canvasTarget.removeEventListener("dragleave", this._boundDragLeave)
      this.canvasTarget.removeEventListener("dragover", this._boundDragOver)
      this.canvasTarget.removeEventListener("drop", this._boundDrop)
    }
  }
  
  // Initialize sortable for the canvas elements
  _initSortable() {
    if (this.hasCanvasTarget) {
      console.log("Initializing sortable for canvas", this.canvasTarget)
      this.canvasSortable = Sortable.create(this.canvasTarget.querySelector("ul") || this.canvasTarget, {
        animation: 150,
        handle: ".drag-handle",
        ghostClass: "sortable-ghost",
        chosenClass: "sortable-chosen",
        dragClass: "sortable-drag",
        onEnd: this._handleSortEnd.bind(this)
      })
    } else {
      console.warn("Canvas target not found for sortable initialization")
    }
  }
  
  // Initialize drag and drop for palette items
  _initDragAndDrop() {
    if (this.hasPaletteTarget) {
      console.log("Initializing drag and drop for palette", this.paletteTarget)
      this.paletteItems = this.paletteTarget.querySelectorAll("[data-draggable]")
      
      // Store bound method references for event cleanup
      this._boundDragStart = this._handleDragStart.bind(this)
      this._boundDragEnd = this._handleDragEnd.bind(this)
      this._boundDragEnter = this._handleDragEnter.bind(this)
      this._boundDragLeave = this._handleDragLeave.bind(this)
      this._boundDragOver = this._handleDragOver.bind(this)
      this._boundDrop = this._handleDrop.bind(this)
      
      console.log(`Found ${this.paletteItems.length} draggable items`)
      
      this.paletteItems.forEach(item => {
        // Set draggable attribute and ensure cursor style
        item.setAttribute("draggable", "true")
        item.style.cursor = "grab"
        
        // Debug message for each draggable item
        console.log("Setting up draggable item:", item.dataset.elementType)
        
        // Add event listeners
        item.addEventListener("dragstart", this._boundDragStart)
        item.addEventListener("dragend", this._boundDragEnd)
      })
      
      if (this.hasCanvasTarget) {
        // Add visual feedback for the drop zone
        this.canvasTarget.addEventListener("dragenter", this._boundDragEnter)
        this.canvasTarget.addEventListener("dragleave", this._boundDragLeave)
        this.canvasTarget.addEventListener("dragover", this._boundDragOver)
        this.canvasTarget.addEventListener("drop", this._boundDrop)
      } else {
        console.warn("Canvas target not found for drag and drop")
      }
    } else {
      console.warn("Palette target not found for drag and drop initialization")
    }
  }
  
  // Handle drag end event
  _handleDragEnd(event) {
    console.log("Drag ended:", event.target.dataset.elementType)
  }
  
  // Handle drag enter event (for visual feedback)
  _handleDragEnter(event) {
    event.preventDefault()
    this.canvasTarget.classList.add("bg-blue-50")
    this.canvasTarget.classList.add("border-blue-300")
    this.canvasTarget.classList.add("border-2")
    this.canvasTarget.classList.add("pulse-border")
    
    // Add a drop indicator
    if (!this.canvasTarget.querySelector('.drop-indicator')) {
      const indicator = document.createElement('div')
      indicator.className = 'drop-indicator absolute inset-0 flex items-center justify-center bg-blue-50 bg-opacity-70 rounded-lg z-10'
      indicator.innerHTML = '<div class="text-center"><svg class="h-10 w-10 mx-auto text-blue-500" fill="none" viewBox="0 0 24 24" stroke="currentColor"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 14l-7 7m0 0l-7-7m7 7V3" /></svg><p class="mt-2 text-sm font-medium text-blue-700">Drop to add element</p></div>'
      
      this.canvasTarget.style.position = 'relative'
      this.canvasTarget.appendChild(indicator)
    }
    
    console.log("Drag entered canvas")
  }
  
  // Handle drag leave event (for visual feedback)
  _handleDragLeave(event) {
    event.preventDefault()
    if (!event.currentTarget.contains(event.relatedTarget)) {
      this.canvasTarget.classList.remove("bg-blue-50")
      this.canvasTarget.classList.remove("border-blue-300")
      this.canvasTarget.classList.remove("border-2")
      this.canvasTarget.classList.remove("pulse-border")
      
      // Remove drop indicator
      const indicator = this.canvasTarget.querySelector('.drop-indicator')
      if (indicator) {
        this.canvasTarget.removeChild(indicator)
      }
      
      console.log("Drag left canvas")
    }
  }
  
  // Handle sort end event
  _handleSortEnd(event) {
    console.log("Sort ended, updating positions")
    const positions = {}
    
    // Collect all elements and their new positions
    this.elementTargets.forEach((element, index) => {
      const elementId = element.dataset.elementId
      positions[elementId] = index
    })
    
    // Send positions to server
    if (Object.keys(positions).length > 0) {
      const url = this.canvasTarget.dataset.positionsUrl
      const csrfToken = document.querySelector('meta[name="csrf-token"]').content
      
      console.log("Updating positions:", positions)
      
      fetch(url, {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          "X-CSRF-Token": csrfToken
        },
        body: JSON.stringify({ positions: positions })
      })
      .then(response => {
        if (!response.ok) {
          console.error("Error updating positions:", response.statusText)
        }
      })
      .catch(error => {
        console.error("Failed to update positions:", error)
      })
    }
  }
  
  // Handle drag start event
  _handleDragStart(event) {
    const elementType = event.target.dataset.elementType
    
    // Set the data that will be available in the drop event
    // Try both ways for maximum compatibility
    event.dataTransfer.setData("application/json", JSON.stringify({ elementType }))
    event.dataTransfer.setData("text/plain", elementType)
    
    event.dataTransfer.effectAllowed = "copy"
    
    console.log("Started dragging element:", elementType)
    
    // Make the drag look nicer in browsers that support it
    try {
      // Create a clone and use it as the drag image if supported
      const dragImage = event.target.cloneNode(true)
      dragImage.style.position = "absolute"
      dragImage.style.top = "-1000px"
      dragImage.style.opacity = "0.8"
      document.body.appendChild(dragImage)
      
      event.dataTransfer.setDragImage(dragImage, 10, 10)
      
      // Clean up the drag image after it's no longer needed
      setTimeout(() => {
        document.body.removeChild(dragImage)
      }, 0)
    } catch (e) {
      console.warn("Browser doesn't support custom drag images", e)
    }
  }
  
  // Handle drag over event
  _handleDragOver(event) {
    event.preventDefault()
    event.dataTransfer.dropEffect = "copy"
  }
  
  // Handle drop event
  _handleDrop(event) {
    event.preventDefault()
    
    // Reset visual feedback
    this.canvasTarget.classList.remove("bg-blue-50")
    this.canvasTarget.classList.remove("border-blue-300")
    this.canvasTarget.classList.remove("border-2")
    this.canvasTarget.classList.remove("pulse-border")
    
    // Remove drop indicator
    const indicator = this.canvasTarget.querySelector('.drop-indicator')
    if (indicator) {
      this.canvasTarget.removeChild(indicator)
    }
    
    // Get the element type from the drag data
    let elementType
    
    try {
      // Try to get the data from JSON first
      const jsonData = event.dataTransfer.getData("application/json")
      if (jsonData) {
        const data = JSON.parse(jsonData)
        elementType = data.elementType
      }
    } catch (e) {
      console.warn("Could not parse JSON drag data:", e)
    }
    
    // Fallback to plain text
    if (!elementType) {
      elementType = event.dataTransfer.getData("text/plain")
    }
    
    console.log("Dropped element, type:", elementType)
    
    if (!elementType) {
      console.error("No element type found in drop data")
      return
    }
    
    // Navigate to the new element form
    this._redirectToNewElementForm(elementType)
  }
  
  // Redirect to the new element form
  _redirectToNewElementForm(elementType) {
    // Find the URL for the new element form
    let url
    
    // First, try to get the URL from our canvas data attribute
    const newElementUrl = this.canvasTarget.dataset.newElementUrl
    
    if (newElementUrl) {
      url = new URL(newElementUrl, window.location.origin)
    } else {
      // Fallback: Try to find the URL from an existing "Add Element" link
      const addElementLink = document.querySelector('a[href*="new_campaign_form_builder_form_builder_element"]')
      
      if (addElementLink) {
        url = new URL(addElementLink.href, window.location.origin)
      }
    }
    
    if (url) {
      // Add the element type parameter to the URL
      url.searchParams.set("element_type", elementType)
      
      console.log("Redirecting to new element form:", url.toString())
      window.location.href = url.toString()
    } else {
      // If we still couldn't find a URL, show an error
      console.error("Could not find URL for new element form")
      alert("Could not create new element. Please use the 'Add Element' button instead.")
    }
  }
  
  // Toggle element preview
  togglePreview(event) {
    const elementId = event.currentTarget.closest("[data-element-id]").dataset.elementId
    const previewElement = this.previewTargets.find(el => el.dataset.elementId === elementId)
    
    if (previewElement) {
      previewElement.classList.toggle("hidden")
    }
  }
  
  // Edit element
  editElement(event) {
    const element = event.currentTarget.closest("[data-element-id]")
    const url = element.dataset.editUrl
    
    if (url) {
      // Navigate to edit page
      window.location.href = url
    } else {
      console.error("No edit URL found for element")
    }
  }
  
  // Delete element
  deleteElement(event) {
    if (!confirm("Are you sure you want to delete this element?")) {
      return
    }
    
    const element = event.currentTarget.closest("[data-element-id]")
    const url = element.dataset.deleteUrl
    
    if (!url) {
      console.error("No delete URL found for element")
      return
    }
    
    // Send delete request
    const csrfToken = document.querySelector('meta[name="csrf-token"]').content
    
    fetch(url, {
      method: "DELETE",
      headers: {
        "X-CSRF-Token": csrfToken,
        "Accept": "text/vnd.turbo-stream.html"
      }
    })
    .then(response => {
      if (!response.ok) {
        console.error("Error deleting element:", response.statusText)
      }
    })
    .catch(error => {
      console.error("Failed to delete element:", error)
    })
  }
  
  // Preview the entire form
  previewForm(event) {
    event.preventDefault()
    const url = event.currentTarget.href
    
    // Open preview in new window
    window.open(url, "form_preview", "width=400,height=600")
  }
}