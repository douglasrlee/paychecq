import { Controller } from "@hotwired/stimulus"

// Tracks when the refresh animation should end (timestamp in ms)
// Global so it persists across Turbo page replacements
let refreshUntil = 0

export default class extends Controller {
  static values = { threshold: { type: Number, default: 80 } }

  // Initializes the controller when it connects to the DOM.
  // Sets up the indicator element and touch event listeners.
  // If a refresh was in progress before Turbo replaced the page,
  // continues showing the spinner for the remaining duration.
  connect() {
    this.startY = 0
    this.hideTimeout = null
    this.indicator = document.getElementById("ptr") || this.createIndicator()

    if (Date.now() < refreshUntil) this.showSpinner(refreshUntil - Date.now())

    // Store bound handlers for cleanup
    this.boundOnStart = this.onStart.bind(this)
    this.boundOnMove = this.onMove.bind(this)
    this.boundOnEnd = this.onEnd.bind(this)

    this.element.addEventListener("touchstart", this.boundOnStart, { passive: true })
    this.element.addEventListener("touchmove", this.boundOnMove, { passive: false })
    this.element.addEventListener("touchend", this.boundOnEnd, { passive: true })
  }

  // Cleans up event listeners and timeout when controller disconnects.
  disconnect() {
    if (this.hideTimeout) clearTimeout(this.hideTimeout)

    this.element.removeEventListener("touchstart", this.boundOnStart)
    this.element.removeEventListener("touchmove", this.boundOnMove)
    this.element.removeEventListener("touchend", this.boundOnEnd)
  }

  // Creates the pull-to-refresh indicator element with spinner and text.
  // Inserts it before the main element (after the nav) so it survives
  // Turbo page replacements.
  createIndicator() {
    const el = document.createElement("div")
    el.id = "ptr"
    el.className = "pull-to-refresh-indicator"
    el.innerHTML = `<div class="ptr-content">
      <svg class="ptr-spinner" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
        <path d="M21 12a9 9 0 1 1-6.219-8.56" stroke-linecap="round"/>
      </svg>
      <span class="ptr-text">Pull to refresh</span>
    </div>`
    this.element.insertAdjacentElement("beforebegin", el)
    return el
  }

  // Handles touch start. Records the starting Y position only if
  // the user is at the top of the scrollable area (scrollTop === 0).
  onStart(e) {
    if (this.element.scrollTop === 0) this.startY = e.touches[0].clientY
  }

  // Handles touch move. Calculates pull distance and updates the indicator
  // height/opacity proportionally. Prevents default scrolling while pulling
  // down to avoid conflicting scroll behavior.
  onMove(e) {
    if (!this.startY) return
    const dist = (e.touches[0].clientY - this.startY) * 0.5
    if (dist > 0) {
      e.preventDefault()
      this.indicator.style.height = `${Math.min(dist, 120)}px`
      this.indicator.style.opacity = Math.min(dist / this.thresholdValue, 1)
      this.indicator.querySelector(".ptr-text").textContent =
        dist >= this.thresholdValue ? "Release to refresh" : "Pull to refresh"
    }
  }

  // Handles touch end. If pulled past the threshold, triggers a refresh.
  // Otherwise, hides the indicator.
  onEnd() {
    const dist = this.indicator.offsetHeight
    this.startY = 0
    if (dist >= this.thresholdValue) {
      this.showSpinner(800)
      refreshUntil = Date.now() + 800
      window.Turbo.visit(location.href, { action: "replace" })
    } else {
      this.hideIndicator()
    }
  }

  // Shows the spinning loader for the specified duration (ms).
  // Automatically hides after the duration elapses.
  showSpinner(duration) {
    this.indicator.style.height = "50px"
    this.indicator.style.opacity = "1"
    this.indicator.querySelector(".ptr-spinner").classList.add("spinning")
    this.indicator.querySelector(".ptr-text").textContent = "Refreshing..."
    this.hideTimeout = setTimeout(() => this.hideIndicator(), duration)
  }

  // Hides the indicator with a smooth slide-up animation.
  hideIndicator() {
    this.indicator.classList.add("hiding")
    this.indicator.style.height = "0"
    this.indicator.style.opacity = "0"
    this.indicator.querySelector(".ptr-spinner").classList.remove("spinning")

    // Remove hiding class after transition completes
    setTimeout(() => this.indicator.classList.remove("hiding"), 200)
  }
}
