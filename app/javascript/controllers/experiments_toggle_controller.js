import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["group", "toggleBtn"]

  toggle() {
    const allOpen = this.groupTargets.every(g => g.open)
    this.groupTargets.forEach(g => g.open = !allOpen)
    this.toggleBtnTarget.textContent = allOpen ? "Expand all" : "Collapse all"
  }
}
