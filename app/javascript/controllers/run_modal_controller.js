import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["modal", "body"]

  open(event) {
    // Don't open modal if clicking buttons/links/forms inside the card
    if (event.target.closest("button, a, form, input")) return

    this.modalTarget.classList.add("is-open")
    document.body.style.overflow = "hidden"
  }

  close(event) {
    // Close on backdrop click or close button
    if (event.target === this.modalTarget || event.target.closest("[data-action*='close']")) {
      this.modalTarget.classList.remove("is-open")
      document.body.style.overflow = ""
    }
  }

  closeKey(event) {
    if (event.key === "Escape") {
      this.modalTarget.classList.remove("is-open")
      document.body.style.overflow = ""
    }
  }
}
