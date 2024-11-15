import { Controller } from '@hotwired/stimulus'

export default class extends Controller {
  static targets = ['form'];

  connect() {
    let isValid = true;

    this.formTarget.addEventListener('submit', event => {
      if (!this.formTarget.checkValidity()) {
        event.preventDefault()
        event.stopPropagation()
      }

      this.formTarget.classList.add('was-validated')
    }, false);

    return isValid;
  }
}
