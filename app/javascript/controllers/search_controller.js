import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["input", "results"]
  static values = { url: String }

  connect() {
    this.timeout = null
  }

  disconnect() {
    clearTimeout(this.timeout)
  }

  search() {
    clearTimeout(this.timeout)
    this.timeout = setTimeout(() => this.fetchResults(), 300)
  }

  async fetchResults() {
    const query = this.inputTarget.value.trim()
    if (query.length < 2) {
      this.resultsTarget.innerHTML = ""
      return
    }

    const url = new URL(this.urlValue, window.location.origin)
    url.searchParams.set("q", query)

    const response = await fetch(url, {
      headers: { "Accept": "text/vnd.turbo-stream.html" }
    })

    if (response.ok) {
      const html = await response.text()
      this.resultsTarget.innerHTML = html
    }
  }
}
