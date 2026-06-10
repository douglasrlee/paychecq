import { Controller } from "@hotwired/stimulus"

const ANIMATION_DURATION = 200

export default class extends Controller {
  connect() {
    this.handleStreamRender = this.handleStreamRender.bind(this)
    document.addEventListener("turbo:before-stream-render", this.handleStreamRender)
  }

  disconnect() {
    document.removeEventListener("turbo:before-stream-render", this.handleStreamRender)
  }

  handleStreamRender(event) {
    const stream = event.detail.newStream
    if (stream.getAttribute("action") !== "remove") return
    if (stream.getAttribute("target") !== this.element.id) return

    this.startDismissAnimation()

    const originalRender = event.detail.render
    event.detail.render = async (streamElement) => {
      await new Promise(resolve => setTimeout(resolve, ANIMATION_DURATION + 20))
      this.maybeShowSiblingEmptyState()
      await originalRender(streamElement)
    }
  }

  maybeShowSiblingEmptyState() {
    const parent = this.element.parentElement
    if (!parent) return
    const remaining = Array.from(parent.querySelectorAll('[data-controller~="dismissible"]'))
      .filter(el => el !== this.element)
    if (remaining.length === 0) {
      const empty = parent.querySelector("[data-empty-state]")
      if (empty) empty.classList.remove("hidden")
    }
  }

  startDismissAnimation() {
    const el = this.element
    const height = el.offsetHeight
    el.style.overflow = "hidden"
    el.style.maxHeight = `${height}px`
    el.style.transition = `max-height ${ANIMATION_DURATION}ms ease-out, opacity ${ANIMATION_DURATION}ms ease-out, margin ${ANIMATION_DURATION}ms ease-out, padding ${ANIMATION_DURATION}ms ease-out`
    requestAnimationFrame(() => {
      el.style.maxHeight = "0"
      el.style.opacity = "0"
      el.style.marginTop = "0"
      el.style.marginBottom = "0"
      el.style.paddingTop = "0"
      el.style.paddingBottom = "0"
    })
  }
}
