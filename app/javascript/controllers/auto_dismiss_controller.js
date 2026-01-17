import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  connect() {
    this.element.classList.add("opacity-0", "transition-opacity", "duration-300");

    requestAnimationFrame(() => {
      this.element.classList.remove("opacity-0");
    });

    setTimeout(() => {
      this.element.classList.add("opacity-0");

      setTimeout(() => this.element.remove(), 300);
    }, 3000);
  }
}
