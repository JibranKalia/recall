import { Controller } from "@hotwired/stimulus"
import { copyText } from "utils/clipboard"

export default class extends Controller {
  static targets = ["source", "button", "label"]

  async copy() {
    const text = this.sourceTarget.textContent
    await copyText(text)

    this.labelTarget.textContent = "Copied!"
    this.buttonTarget.classList.add("copied")

    setTimeout(() => {
      this.labelTarget.textContent = "Copy"
      this.buttonTarget.classList.remove("copied")
    }, 2000)
  }
}
