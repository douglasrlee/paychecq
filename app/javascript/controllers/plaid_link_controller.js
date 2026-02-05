import { Controller } from "@hotwired/stimulus";
import { Turbo } from "@hotwired/turbo-rails";

export default class extends Controller {
  static values = {
    token: String
  };

  static targets = ["button"];

  connect() {
    this.loadPlaidScript().then(() => {
      this.initializePlaid();
    });
  }

  loadPlaidScript() {
    return new Promise((resolve) => {
      if (window.Plaid) {
        resolve();

        return;
      }

      const script = document.createElement("script");
      script.src = "https://cdn.plaid.com/link/v2/stable/link-initialize.js";
      script.onload = resolve;

      document.head.appendChild(script);
    });
  }

  initializePlaid() {
    if (!this.tokenValue) {
      console.error("Plaid link token not provided");

      return;
    }

    this.handler = window.Plaid.create({
      token: this.tokenValue,

      onSuccess: (publicToken, metadata) => this.onSuccess(publicToken, metadata),
      onExit: (error) => this.onExit(error),
      onEvent: () => this.onEvent()
    });
  }

  open(event) {
    event.preventDefault();

    if (this.handler) {
      this.handler.open();
    }
  }

  async onSuccess(publicToken, metadata) {
    this.setLoading(true);

    try {
      const csrfToken = document.querySelector("meta[name='csrf-token']")?.content;

      const formData = new FormData();
      formData.append("public_token", publicToken);
      formData.append("institution_id", metadata.institution.institution_id);
      formData.append("institution_name", metadata.institution.name);

      const response = await fetch("/banks", {
        method: "POST",
        headers: {
          "X-CSRF-Token": csrfToken,
          "Accept": "text/vnd.turbo-stream.html, text/html, application/xhtml+xml"
        },
        body: formData
      });

      if (response.redirected) {
        Turbo.visit(response.url);
      } else {
        Turbo.visit("/settings");
      }
    } catch (error) {
      console.error("Failed to link bank:", error);

      this.setLoading(false);
      
      Turbo.visit("/settings");
    }
  }

  setLoading(isLoading) {
    if (!this.hasButtonTarget) return;

    if (isLoading) {
      this.buttonTarget.disabled = true;
      this.originalButtonContent = this.buttonTarget.innerHTML;
      this.buttonTarget.innerHTML = '<span class="loading loading-spinner loading-sm"></span> Linking...';
    } else {
      this.buttonTarget.disabled = false;
      this.buttonTarget.innerHTML = this.originalButtonContent;
    }
  }

  onExit(error) {
    if (error) {
      console.error("Plaid Link error:", error);
    }
  }

  onEvent() {
    // Optional: track events for analytics
  }

  disconnect() {
    if (this.handler) {
      this.handler.destroy();
    }
  }
}
