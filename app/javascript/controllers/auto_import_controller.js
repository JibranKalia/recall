import { Controller } from "@hotwired/stimulus"

// Auto-submits the import form 15 minutes after the last one.
// Submits to the base URL (no session_id) for a full import,
// even on session pages where manual clicks include session_id.
// Before submitting, checks the server to see if another tab/profile
// already triggered an import — only one actually fires.
const STALE_MS = 15 * 60 * 1000 // 15 minutes
const JITTER_MS = 60 * 1000     // 0–60s random jitter to stagger tabs

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
    const remaining = Math.max(0, STALE_MS - (Date.now() - lastAt))
    const jitter = Math.random() * JITTER_MS
    this.timer = setTimeout(() => this.#checkAndSubmit(), remaining + jitter)
  }

  async #checkAndSubmit() {
    try {
      const resp = await fetch(`${this.urlValue}/status`)
      const data = await resp.json()

      if (data.running) {
        this.#scheduleNext()
        return
      }

      if (data.last_import_at) {
        const serverLastAt = new Date(data.last_import_at).getTime()
        if (Date.now() - serverLastAt < STALE_MS) {
          // Another tab already imported — update our value and reschedule
          this.lastImportAtValue = data.last_import_at
          this.#scheduleNext()
          return
        }
      }
    } catch {
      // Server unreachable — skip this cycle
      this.#scheduleNext()
      return
    }

    this.#submit()
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
