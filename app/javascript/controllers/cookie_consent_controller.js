import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  connect() {
    if (!this.#getCookie("cookie_consent")) {
      this.element.classList.remove("d-none")
    }
  }

  accept() {
    const maxAge = 365 * 24 * 60 * 60 // 1 year in seconds
    document.cookie = `cookie_consent=accepted; path=/; max-age=${maxAge}; SameSite=Lax`
    this.element.classList.add("d-none")
  }

  #getCookie(name) {
    return document.cookie.split("; ").find(row => row.startsWith(name + "="))
  }
}
