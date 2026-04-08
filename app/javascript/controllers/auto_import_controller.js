import { Controller } from "@hotwired/stimulus"

// Auto-submits the import form 30 minutes after the last one.
// Submits to the base URL (no session_id) for a full import,
// even on session pages where manual clicks include session_id.
// The backend guards against duplicate runs, so multiple tabs are safe.
const STALE_MS = 30 * 60 * 1000 // 30 minutes

export default class extends Controller {
  static values = { lastImportAt: String, url: String }

  connect() {
    this.element.addEventListener("turbo:submit-end", this.#handleSubmitEnd.bind(this))
    this.#scheduleNext()
  }

  disconnect() {
    clearTimeout(this.timer)
  }

  // --- private ---

  #scheduleNext() {
    clearTimeout(this.timer)
    const lastAt = this.lastImportAtValue ? new Date(this.lastImportAtValue).getTime() : 0
    const delay = Math.max(0, STALE_MS - (Date.now() - lastAt))
    this.timer = setTimeout(() => this.#submit(), delay)
  }

  #submit() {
    const originalAction = this.element.action
    this.element.action = this.urlValue
    this.element.requestSubmit()
    this.element.action = originalAction
  }

  #handleSubmitEnd() {
    this.lastImportAtValue = new Date().toISOString()
    this.#scheduleNext()
  }
}
