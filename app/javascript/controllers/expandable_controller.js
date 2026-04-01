import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["item", "button"]
  static values = { limit: { type: Number, default: 3 } }

  toggle() {
    const expanded = this.element.classList.toggle("expanded")
    this.itemTargets.forEach(el => el.classList.toggle("search-result-hidden", !expanded))
    this.buttonTarget.textContent = expanded
      ? "Show less"
      : `Show ${this.itemTargets.length} more`
  }
}
