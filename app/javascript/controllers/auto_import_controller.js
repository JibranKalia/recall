import { Controller } from "@hotwired/stimulus"

// Auto-submits the import form 30 minutes after the last import.
// The backend guards against duplicate runs, so multiple tabs are safe.
const STALE_MS = 30 * 60 * 1000 // 30 minutes

export default class extends Controller {
  static values = { lastImportAt: String }

  connect() {
    this.#scheduleNext()
  }

  disconnect() {
    clearTimeout(this.timer)
  }

  // --- private ---

  #scheduleNext() {
    const lastAt = this.lastImportAtValue ? new Date(this.lastImportAtValue).getTime() : 0
    const delay = Math.max(0, STALE_MS - (Date.now() - lastAt))

    this.timer = setTimeout(() => {
      // Skip if a manual import is already in progress (button shows spinner)
      const btn = this.element.querySelector(".nav-refresh")
      if (btn?.classList.contains("pending")) return

      this.element.requestSubmit()
    }, delay)
  }
}
