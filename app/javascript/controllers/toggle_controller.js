import { Controller } from "@hotwired/stimulus"

const ANIMATION_DURATION = 200

export default class extends Controller {
  static targets = ["content"]
  static values = { delayFrame: String }

  connect() {
    this.handleStreamRender = this.handleStreamRender.bind(this)
    document.addEventListener("turbo:before-stream-render", this.handleStreamRender)
  }

  disconnect() {
    document.removeEventListener("turbo:before-stream-render", this.handleStreamRender)
  }

  close() {
    const content = this.contentTarget
    if (!content.classList.contains("hidden")) this.slideClose(content)
  }

  toggle() {
    const content = this.contentTarget
    if (content.classList.contains("hidden")) {
      this.slideOpen(content)
    } else {
      this.slideClose(content)
    }
  }

  // Used by forms inside the toggle so the toggle only collapses on a
  // successful submit; on validation errors the form stays open.
  closeOnSuccess(event) {
    if (event.detail.success) this.close()
  }

  // Delay stream renders targeting our frame so the close animation finishes first
  handleStreamRender(event) {
    if (!this.delayFrameValue) return

    const stream = event.detail.newStream
    const action = stream.getAttribute("action")
    const target = stream.getAttribute("target")
    const isFrameUpdate = [ "update", "replace" ].includes(action) && target === this.delayFrameValue

    if (isFrameUpdate) {
      const originalRender = event.detail.render
      event.detail.render = async (streamElement) => {
        await new Promise(resolve => setTimeout(resolve, ANIMATION_DURATION + 20))
        await originalRender(streamElement)
      }
    }
  }

  slideOpen(content) {
    content.classList.remove("hidden")
    content.style.overflow = "hidden"
    content.style.maxHeight = "0"
    content.style.transition = `max-height ${ANIMATION_DURATION}ms ease-out`
    requestAnimationFrame(() => {
      content.style.maxHeight = content.scrollHeight + "px"
    })
    content.addEventListener("transitionend", () => {
      content.style.maxHeight = ""
      content.style.overflow = ""
      content.style.transition = ""
    }, { once: true })
  }

  slideClose(content) {
    content.style.maxHeight = content.scrollHeight + "px"
    content.style.overflow = "hidden"
    content.style.transition = `max-height ${ANIMATION_DURATION}ms ease-out`
    requestAnimationFrame(() => {
      content.style.maxHeight = "0"
    })
    content.addEventListener("transitionend", () => {
      content.classList.add("hidden")
      content.style.maxHeight = ""
      content.style.overflow = ""
      content.style.transition = ""
    }, { once: true })
  }
}
