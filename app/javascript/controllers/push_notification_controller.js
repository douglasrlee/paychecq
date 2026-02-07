import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = { vapidPublicKey: String }
  static targets = ["toggle"]

  async connect() {
    if (!("serviceWorker" in navigator) || !("PushManager" in window)) {
      this.element.hidden = true
      return
    }

    const registration = await navigator.serviceWorker.ready
    const subscription = await registration.pushManager.getSubscription()

    if (this.hasToggleTarget) {
      this.toggleTarget.checked = !!subscription
    }
  }

  async toggle(event) {
    this.toggleTarget.disabled = true

    try {
      if (event.target.checked) {
        await this.subscribe()
      } else {
        await this.unsubscribe()
      }
    } finally {
      this.toggleTarget.disabled = false
    }
  }

  async subscribe() {
    const permission = await Notification.requestPermission()

    if (permission !== "granted") {
      this.toggleTarget.checked = false
      return
    }

    try {
      const registration = await navigator.serviceWorker.ready
      const subscription = await registration.pushManager.subscribe({
        userVisibleOnly: true,
        applicationServerKey: this.urlBase64ToUint8Array(this.vapidPublicKeyValue)
      })

      await this.saveSubscription(subscription)
    } catch (error) {
      console.error("Push subscription failed:", error)
      this.toggleTarget.checked = false
    }
  }

  async unsubscribe() {
    try {
      const registration = await navigator.serviceWorker.ready
      const subscription = await registration.pushManager.getSubscription()

      if (subscription) {
        await subscription.unsubscribe()
        await this.deleteSubscription(subscription.endpoint)
      }
    } catch (error) {
      console.error("Push unsubscribe failed:", error)
      this.toggleTarget.checked = true
    }
  }

  async saveSubscription(subscription) {
    const csrfToken = document.querySelector("meta[name='csrf-token']")?.content

    await fetch("/push_subscription", {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        "X-CSRF-Token": csrfToken
      },
      body: JSON.stringify({ push_subscription: subscription.toJSON() })
    })
  }

  async deleteSubscription(endpoint) {
    const csrfToken = document.querySelector("meta[name='csrf-token']")?.content

    await fetch("/push_subscription", {
      method: "DELETE",
      headers: {
        "Content-Type": "application/json",
        "X-CSRF-Token": csrfToken
      },
      body: JSON.stringify({ endpoint })
    })
  }

  urlBase64ToUint8Array(base64String) {
    const padding = "=".repeat((4 - (base64String.length % 4)) % 4)
    const base64 = (base64String + padding).replace(/-/g, "+").replace(/_/g, "/")
    const rawData = atob(base64)
    return Uint8Array.from([...rawData].map((char) => char.charCodeAt(0)))
  }
}
