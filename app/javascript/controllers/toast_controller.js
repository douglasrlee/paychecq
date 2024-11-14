import { Controller } from '@hotwired/stimulus'

export default class extends Controller {
  static targets = ['toast']

  connect() {
    bootstrap.Toast.getOrCreateInstance(this.toastTarget).show();
  }
}
