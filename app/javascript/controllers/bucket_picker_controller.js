import { Controller } from "@hotwired/stimulus"

// Drives the single "Assign" picker in the transaction drawer over both
// expenses and goals. Typing filters the list; selecting one points the form
// at the right endpoint (expenses vs goals) and names the hidden id field
// accordingly, so one form serves both bucket types.
export default class extends Controller {
  static targets = ["input", "search", "option", "group", "submit"]
  static values = { expenseUrl: String, goalUrl: String }

  select(event) {
    event.preventDefault()
    const { id, type } = event.currentTarget.dataset

    this.inputTarget.value = id
    this.inputTarget.name = type === "goal" ? "goal_id" : "expense_id"
    this.element.action = type === "goal" ? this.goalUrlValue : this.expenseUrlValue

    this.optionTargets.forEach((option) => {
      const button = option.querySelector("button")
      const selected = button.dataset.id === id
      button.querySelector(".picker-check")?.classList.toggle("invisible", !selected)
    })

    if (this.hasSubmitTarget) this.submitTarget.disabled = false
  }

  filter() {
    const query = this.searchTarget.value.trim().toLowerCase()

    this.optionTargets.forEach((option) => {
      const match = query === "" || option.dataset.name.includes(query)
      option.classList.toggle("hidden", !match)
    })

    // Hide a group heading when none of its options are visible.
    this.groupTargets.forEach((group) => {
      let sibling = group.nextElementSibling
      let anyVisible = false
      while (sibling && !this.groupTargets.includes(sibling)) {
        if (!sibling.classList.contains("hidden")) anyVisible = true
        sibling = sibling.nextElementSibling
      }
      group.classList.toggle("hidden", !anyVisible)
    })
  }
}
