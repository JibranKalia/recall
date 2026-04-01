import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["icon"]

  async run() {
    this.iconTarget.classList.add("spinning")
    try {
      await fetch("/import", { method: "POST" })
      window.location.reload()
    } catch (e) {
      this.iconTarget.classList.remove("spinning")
    }
  }
}
