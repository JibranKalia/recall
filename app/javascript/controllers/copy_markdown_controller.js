import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["label"]
  static values = { url: String }

  async copy() {
    try {
      const response = await fetch(this.urlValue)
      const text = await response.text()
      await navigator.clipboard.writeText(text)

      this.labelTarget.textContent = "Copied!"
      this.element.classList.add("copied")

      setTimeout(() => {
        this.labelTarget.textContent = "Copy as Markdown"
        this.element.classList.remove("copied")
      }, 2000)
    } catch (error) {
      this.labelTarget.textContent = "Failed"
      setTimeout(() => {
        this.labelTarget.textContent = "Copy as Markdown"
      }, 2000)
    }
  }
}
