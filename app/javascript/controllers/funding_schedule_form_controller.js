import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["cadenceInput", "secondDayField"]

  connect() {
    this.update()
  }

  cadenceChanged() {
    this.update()
  }

  update() {
    const checked = this.cadenceInputTargets.find((input) => input.checked)
    const isSemimonthly = checked?.value === "semimonthly"
    this.secondDayFieldTarget.classList.toggle("hidden", !isSemimonthly)
  }
}
