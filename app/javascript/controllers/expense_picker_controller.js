import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["input", "label", "option", "submit"]

  select(event) {
    event.preventDefault()
    const { id, name } = event.currentTarget.dataset
    this.inputTarget.value = id
    this.labelTarget.textContent = name
    this.labelTarget.classList.remove("text-base-content/50")

    this.optionTargets.forEach((option) => {
      const isSelected = option.dataset.id === id
      option.querySelector(".picker-check")?.classList.toggle("invisible", !isSelected)
    })

    if (this.hasSubmitTarget) this.submitTarget.disabled = false

    document.activeElement?.blur()
  }
}
