import { Controller } from "@hotwired/stimulus";

export default class extends Controller {
  static values = {
    text: { type: String, default: "Loading..." }
  };

  connect() {
    this.element.addEventListener("click", this.showLoading);
  }

  disconnect() {
    this.element.removeEventListener("click", this.showLoading);
  }

  showLoading = () => {
    this.originalContent = this.element.innerHTML;
    this.element.innerHTML = `<span class="loading loading-spinner loading-sm"></span> ${this.textValue}`;
    this.element.classList.add("pointer-events-none", "opacity-70");

    if (this.element.tagName === "BUTTON") {
      this.element.disabled = true;
    }
  };
}
