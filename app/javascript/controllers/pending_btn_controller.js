import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["btn"]

  submit() {
    this.btnTarget.disabled = true
    this.btnTarget.classList.add("pending")
  }
}
