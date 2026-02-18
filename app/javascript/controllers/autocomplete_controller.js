import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["input", "results"]
  static values = {
    url: String,
    debounce: { type: Number, default: 300 },
    minLength: { type: Number, default: 2 }
  }

  connect() {
    this.debounceTimer = null
  }

  disconnect() {
    this.clearDebounce()
  }

  search(event) {
    const query = event.target.value.trim()

    this.clearDebounce()

    if (query.length < this.minLengthValue) {
      this.hideResults()
      return
    }

    this.debounceTimer = setTimeout(() => {
      this.fetchResults(query)
    }, this.debounceValue)
  }

  async fetchResults(query) {
    try {
      const response = await fetch(`${this.urlValue}?q=${encodeURIComponent(query)}`, {
        headers: { "Accept": "application/json" }
      })
      const data = await response.json()
      this.displayResults(data)
    } catch (error) {
      console.error("Autocomplete error:", error)
    }
  }

  displayResults(data) {
    if (!data || data.length === 0) {
      this.hideResults()
      return
    }

    this.resultsTarget.innerHTML = data.map(item => {
      const subtitle = item.subtitle ? `<div class="autocomplete-subtitle">${item.subtitle}</div>` : ""
      return `
        <a href="${item.url}" class="autocomplete-item">
          <span class="autocomplete-type autocomplete-type-${item.type.toLowerCase()}">${item.type}</span>
          <div class="autocomplete-content">
            <div class="autocomplete-title">${item.title}</div>
            ${subtitle}
          </div>
        </a>
      `
    }).join("")

    this.resultsTarget.style.display = "block"
  }

  hideResults() {
    this.resultsTarget.style.display = "none"
    this.resultsTarget.innerHTML = ""
  }

  clearDebounce() {
    if (this.debounceTimer) {
      clearTimeout(this.debounceTimer)
      this.debounceTimer = null
    }
  }

  handleEscape(event) {
    if (event.key === "Escape") {
      this.hideResults()
    }
  }

  clickOutside(event) {
    if (!this.element.contains(event.target)) {
      this.hideResults()
    }
  }
}
