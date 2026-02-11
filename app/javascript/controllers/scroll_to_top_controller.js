import { Controller } from "@hotwired/stimulus";

const MOBILE_QUERY = "(max-width: 1023px)";

export default class extends Controller {
  scroll(event) {
    if (!window.matchMedia(MOBILE_QUERY).matches) return;
    if (event.target.closest("a, button, [role='button'], .dropdown")) return;

    document.querySelector("main")?.scrollTo({ top: 0, behavior: "smooth" });
  }
}
