import { Controller } from "@hotwired/stimulus"

// Lives on each run card. On click, dispatches content to the shared run-modal.
export default class extends Controller {
  static targets = ["metrics", "response"]
  static values = { provider: String, model: String }

  open(event) {
    if (event.target.closest("button, a, form, input")) return
    if (!this.hasResponseTarget) return

    const modal = document.querySelector("[data-controller='run-modal']")
    if (!modal) return

    modal.dispatchEvent(new CustomEvent("run-card:open", {
      detail: {
        provider: this.providerValue,
        model: this.modelValue,
        metrics: this.metricsTarget.innerHTML,
        html: this.responseTarget.innerHTML
      }
    }))
  }
}
