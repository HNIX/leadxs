import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["sidebar", "content", "overlay"]

  connect() {
    // Check if the sidebar should be open based on screen size or stored preference
    this.checkSidebarState()
    
    // Listen for window resize events
    window.addEventListener('resize', this.checkSidebarState.bind(this))
  }

  disconnect() {
    window.removeEventListener('resize', this.checkSidebarState.bind(this))
  }

  toggleSidebar() {
    const sidebarEl = this.sidebarTarget
    const isClosed = sidebarEl.getAttribute('data-state') === 'closed'
    
    if (isClosed) {
      this.openSidebar()
    } else {
      this.closeSidebar()
    }
  }

  openSidebar() {
    this.sidebarTarget.setAttribute('data-state', 'open')
    this.sidebarTarget.classList.remove('-translate-x-full')
    this.sidebarTarget.classList.add('translate-x-0')
    
    // Only show overlay on mobile
    if (this.hasOverlayTarget && window.innerWidth < 1024) {
      this.overlayTarget.classList.remove('hidden')
      setTimeout(() => {
        this.overlayTarget.classList.remove('opacity-0')
        this.overlayTarget.classList.add('opacity-50')
      }, 50)
    }
    
    // No need to store mobile preferences
    if (window.innerWidth >= 1024) {
      localStorage.setItem('sidebarOpen', 'true')
    }
    
    // Add class to prevent scrolling on body when sidebar is open on mobile
    if (window.innerWidth < 1024) {
      document.body.classList.add('overflow-hidden', 'lg:overflow-auto')
    }
  }

  closeSidebar() {
    this.sidebarTarget.setAttribute('data-state', 'closed')
    this.sidebarTarget.classList.remove('translate-x-0')
    this.sidebarTarget.classList.add('-translate-x-full')
    
    if (this.hasOverlayTarget) {
      this.overlayTarget.classList.add('opacity-0')
      this.overlayTarget.classList.remove('opacity-50')
      setTimeout(() => {
        this.overlayTarget.classList.add('hidden')
      }, 300)
    }
    
    // No need to store mobile preferences
    if (window.innerWidth >= 1024) {
      localStorage.setItem('sidebarOpen', 'false')
    }
    
    // Remove overflow hidden class from body
    document.body.classList.remove('overflow-hidden', 'lg:overflow-auto')
  }

  checkSidebarState() {
    // For mobile (under 1024px/lg breakpoint), always start with sidebar closed
    if (window.innerWidth < 1024) {
      this.closeSidebar()
    } else {
      // For desktop, sidebar is always visible (controlled by CSS), but we still set the state
      this.sidebarTarget.setAttribute('data-state', 'open')
      this.sidebarTarget.classList.remove('-translate-x-full')
      this.sidebarTarget.classList.add('translate-x-0')
    }
  }

  // Close sidebar when clicking overlay on mobile
  closeFromOverlay() {
    this.closeSidebar()
  }
}