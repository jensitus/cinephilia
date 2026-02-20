import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["menu"]

  toggle(event) {
    event.preventDefault()
    this.menuTarget.classList.toggle("show")
  }

  hide(event) {
    if (!this.element.contains(event.target)) {
      this.menuTarget.classList.remove("show")
    }
  }

  connect() {
    this.hideHandler = this.hide.bind(this)
    document.addEventListener("click", this.hideHandler)
  }

  disconnect() {
    document.removeEventListener("click", this.hideHandler)
  }
}
