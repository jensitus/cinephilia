import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["toggleBtn", "mapContainer", "directionsContainer"]
  static values = { street: String, zip: String, city: String }

  connect() {
    if (this.#isMobile()) {
      this.mapContainerTarget.style.display = "none"
      this.directionsContainerTarget.style.display = "none"
    } else {
      this.toggleBtnTarget.style.display = "none"
      this.#geocodeAndInit()
    }
  }

  disconnect() {
    if (this.map) {
      this.map.remove()
      this.map = null
    }
  }

  toggle() {
    const container = this.mapContainerTarget
    const btn = this.toggleBtnTarget
    const hidden = container.style.display === "none"

    container.style.display = hidden ? "block" : "none"
    this.directionsContainerTarget.style.display = hidden ? "block" : "none"
    btn.textContent = hidden ? "Hide map" : "Show map"

    if (hidden) {
      if (!this.map) {
        this.#geocodeAndInit()
      } else {
        this.map.invalidateSize()
      }
    }
  }

  #isMobile() {
    return window.innerWidth < 1200
  }

  #geocodeAndInit() {
    const street = this.streetValue.replace(/\s*\(.*?\)\s*/g, "").replace(/\s*\/.*$/, "").trim()
    const query = [street, this.zipValue, this.cityValue].filter(Boolean).join(", ")
    if (!query) return

    fetch(`https://nominatim.openstreetmap.org/search?q=${encodeURIComponent(query)}&format=json&limit=1`, {
      headers: { "Accept-Language": "en" }
    })
      .then(r => r.json())
      .then(results => {
        if (!results.length) return
        const { lat, lon } = results[0]
        this.#initMap(parseFloat(lat), parseFloat(lon))
      })
      .catch(() => {})
  }

  #initMap(lat, lon) {
    const L = window.L
    if (!L) return

    this.map = L.map(this.mapContainerTarget).setView([lat, lon], 16)

    L.tileLayer("https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png", {
      attribution: '&copy; <a href="https://www.openstreetmap.org/copyright">OpenStreetMap</a> contributors',
      maxZoom: 19
    }).addTo(this.map)

    L.marker([lat, lon]).addTo(this.map)

    const link = document.createElement("a")
    link.href = `https://www.openstreetmap.org/directions?to=${lat}%2C${lon}`
    link.target = "_blank"
    link.rel = "noopener"
    link.className = "btn btn-sm btn-outline-secondary mt-2"
    link.textContent = "Get directions"
    this.directionsContainerTarget.appendChild(link)
  }
}
