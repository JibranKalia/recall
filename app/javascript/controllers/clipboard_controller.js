import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["source", "button", "label"]

  async copy() {
    const text = this.sourceTarget.textContent
    await navigator.clipboard.writeText(text)

    this.labelTarget.textContent = "Copied!"
    this.buttonTarget.classList.add("copied")

    setTimeout(() => {
      this.labelTarget.textContent = "Copy"
      this.buttonTarget.classList.remove("copied")
    }, 2000)
  }
}
