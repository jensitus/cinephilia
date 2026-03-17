import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["content", "button"]
  static values = {
    showText: { type: String, default: "Show more" },
    hideText: { type: String, default: "Show less" },
    count: Number,
    currentSection: { type: Boolean, default: false }
  }

  connect() {
    this.visible = false
  }

  toggle() {
    this.visible = !this.visible

    if (this.visible) {
      this.contentTarget.style.display = "grid"
      this.buttonTarget.textContent = this.hideTextValue
    } else {
      this.contentTarget.style.display = "none"
      this.buttonTarget.textContent = this.buildShowText()
    }
  }

  buildShowText() {
    const count = this.hasCountValue ? this.countValue : ""
    if (this.currentSectionValue) {
      return `Show ${count} more currently showing`
    }
    return `Show ${count} more`
  }
}
