import { Controller } from "@hotwired/stimulus";

export default class extends Controller {
  scroll(event) {
    if (event.target.closest("a, button, [role='button'], .dropdown")) return;

    document.querySelector("main")?.scrollTo({ top: 0, behavior: "smooth" });
  }
}
