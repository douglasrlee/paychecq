import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = {
    token: String
  }

  connect() {
    this.loadPlaidScript().then(() => {
      this.initializePlaid()
    })
  }

  loadPlaidScript() {
    return new Promise((resolve) => {
      if (window.Plaid) {
        resolve()
        
        return
      }

      const script = document.createElement("script")
      script.src = "https://cdn.plaid.com/link/v2/stable/link-initialize.js"
      script.onload = resolve

      document.head.appendChild(script)
    })
  }

  initializePlaid() {
    if (!this.tokenValue) {
      console.error("Plaid link token not provided")
      
      return
    }

    this.handler = window.Plaid.create({
      token: this.tokenValue,
      
      onSuccess: (publicToken, metadata) => this.onSuccess(publicToken, metadata),
      onExit: (error) => this.onExit(error),
      onEvent: () => this.onEvent()
    })
  }

  open(event) {
    event.preventDefault()
    
    if (this.handler) {
      this.handler.open()
    }
  }

  onSuccess(publicToken, metadata) {
    const form = document.createElement("form")
    form.method = "POST"
    form.action = "/banks"

    const csrfToken = document.querySelector("meta[name='csrf-token']").content
    const csrfInput = document.createElement("input")
    csrfInput.type = "hidden"
    csrfInput.name = "authenticity_token"
    csrfInput.value = csrfToken
    
    form.appendChild(csrfInput)

    const tokenInput = document.createElement("input")
    tokenInput.type = "hidden"
    tokenInput.name = "public_token"
    tokenInput.value = publicToken
    
    form.appendChild(tokenInput)

    const institutionIdInput = document.createElement("input")
    institutionIdInput.type = "hidden"
    institutionIdInput.name = "institution_id"
    institutionIdInput.value = metadata.institution.institution_id
    
    form.appendChild(institutionIdInput)

    const institutionNameInput = document.createElement("input")
    institutionNameInput.type = "hidden"
    institutionNameInput.name = "institution_name"
    institutionNameInput.value = metadata.institution.name
    
    form.appendChild(institutionNameInput)

    document.body.appendChild(form)
    
    form.submit()
  }

  onExit(error) {
    if (error) {
      console.error("Plaid Link error:", error)
    }
  }

  onEvent() {
    // Optional: track events for analytics
  }

  disconnect() {
    if (this.handler) {
      this.handler.destroy()
    }
  }
}
