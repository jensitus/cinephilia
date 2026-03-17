import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["content", "button"]
  static values = {
    count: Number
  }

  connect() {
    this.visible = false
  }

  toggle() {
    this.visible = !this.visible

    if (this.visible) {
      this.contentTarget.style.display = "block"
      this.buttonTarget.textContent = "Show less"
    } else {
      this.contentTarget.style.display = "none"
      this.buttonTarget.textContent = `Show ${this.countValue} more`
    }
  }
}
