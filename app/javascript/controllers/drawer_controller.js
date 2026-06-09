import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["panel", "overlay"]

  connect() {
    this.handleEscape = this.handleEscape.bind(this)
  }

  open() {
    this.overlayTarget.classList.remove("opacity-0", "pointer-events-none")
    this.panelTarget.classList.remove("translate-x-full")
    document.addEventListener("keydown", this.handleEscape)
  }

  close() {
    this.overlayTarget.classList.add("opacity-0", "pointer-events-none")
    this.panelTarget.classList.add("translate-x-full")
    document.removeEventListener("keydown", this.handleEscape)
  }

  handleEscape(event) {
    if (event.key === "Escape") this.close()
  }

  disconnect() {
    document.removeEventListener("keydown", this.handleEscape)
  }
}
