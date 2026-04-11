import { Controller } from "@hotwired/stimulus"

// Lives on the shared modal overlay element (one per page).
// Run cards dispatch `run-modal:open` with their content to populate and open it.
export default class extends Controller {
  static targets = ["header", "body"]

  open({ detail: { provider, model, metrics, html } }) {
    this.headerTarget.innerHTML = `
      <span class="run-provider-name">${provider}</span>
      <span class="run-model-tag">${model}</span>
      <div class="run-metrics run-metrics--borderless">${metrics}</div>
    `
    this.bodyTarget.innerHTML = html
    this.element.classList.add("is-open")
    document.body.style.overflow = "hidden"
  }

  close(event) {
    if (event.target === this.element || event.target.closest(".run-modal-close")) {
      this.#dismiss()
    }
  }

  closeKey(event) {
    if (event.key === "Escape") this.#dismiss()
  }

  #dismiss() {
    this.element.classList.remove("is-open")
    document.body.style.overflow = ""
  }
}
