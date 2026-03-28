import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  toggle(event) {
    if (this.element.classList.contains("expanded")) {
      this.element.classList.remove("expanded")
    } else {
      event.preventDefault()
      this.element.classList.add("expanded")
    }
  }
}
