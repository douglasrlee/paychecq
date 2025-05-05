import { Controller } from '@hotwired/stimulus';

export default class extends Controller {
  connect() {
    const prefersDarkScheme = window.matchMedia('(prefers-color-scheme: dark)');

    prefersDarkScheme.addEventListener('change', (event) => {
      setTheme(event.matches);
    });

    setTheme(prefersDarkScheme.matches);
  }
}
