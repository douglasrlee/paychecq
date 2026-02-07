// Entry point for the build script in your package.json
import "@hotwired/turbo-rails"
import "./controllers"

if ("serviceWorker" in navigator) {
  navigator.serviceWorker.register("/service-worker", { scope: "/" })
}
