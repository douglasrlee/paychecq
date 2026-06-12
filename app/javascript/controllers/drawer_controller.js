import { Controller } from "@hotwired/stimulus"

const LOADING_TEMPLATE = `
  <div role="status" aria-live="polite" class="absolute inset-0 flex items-center justify-center">
    <span class="loading loading-spinner loading-lg text-base-content/40" aria-hidden="true"></span>
    <span class="sr-only">Loading transaction</span>
  </div>
`

export default class extends Controller {
  static targets = ["panel", "overlay"]

  connect() {
    this.handleEscape = this.handleEscape.bind(this)
  }

  open() {
    this.resetContent()
    this.overlayTarget.classList.remove("opacity-0", "pointer-events-none")
    this.panelTarget.classList.remove("translate-x-full")
    document.addEventListener("keydown", this.handleEscape)
  }

  close(event) {
    if (event) event.preventDefault()
    this.overlayTarget.classList.add("opacity-0", "pointer-events-none")
    this.panelTarget.classList.add("translate-x-full")
    document.removeEventListener("keydown", this.handleEscape)
  }

  handleEscape(event) {
    if (event.key === "Escape") this.close()
  }

  // Clear stale content and show a loading state before Turbo fetches the new frame.
  // Runs synchronously in the click handler, so it lands before Turbo's navigation.
  resetContent() {
    const frame = document.getElementById("drawer_content")
    if (frame) frame.innerHTML = LOADING_TEMPLATE
  }

  disconnect() {
    document.removeEventListener("keydown", this.handleEscape)
  }
}
