import { Controller } from "@hotwired/stimulus"

const BASE_MS = 30 * 1000
const JITTER_MS = 10 * 1000

export default class extends Controller {
  connect() {
    this.element.addEventListener("turbo:submit-end", this.#onSubmitEnd.bind(this))
    this.#scheduleNext()
  }

  disconnect() {
    clearTimeout(this.timer)
  }

  #scheduleNext() {
    clearTimeout(this.timer)
    const jitter = (Math.random() * 2 - 1) * JITTER_MS
    this.timer = setTimeout(() => this.element.requestSubmit(), BASE_MS + jitter)
  }

  #onSubmitEnd() {
    this.#scheduleNext()
    setTimeout(() => {
      window.scrollTo({ top: document.body.scrollHeight, behavior: "smooth" })
    }, 250)
  }
}
