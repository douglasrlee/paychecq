// Configure your import map in config/importmap.rb. Read more: https://github.com/rails/importmap-rails
import "@hotwired/turbo-rails"
import "controllers"
import * as bootstrap from "bootstrap"

//#region auto favicon
const usesDarkMode = window.matchMedia('(prefers-color-scheme: dark)').matches || false;
const favicon = document.getElementById('favicon');

function switchIcon(usesDarkMode) {
  if (usesDarkMode) {
    favicon.href = '/dark/dark-logo.png';
  } else {
    favicon.href = '/light/light-logo.png';
  }
}

window
    .matchMedia('(prefers-color-scheme: dark)')
    .addEventListener('change', (e) => switchIcon(e.matches));

switchIcon(usesDarkMode);
//#endregion
