import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["label", "menu"]
  static values = { url: String }

  toggle() {
    this.menuTarget.classList.toggle("hidden")
  }

  close() {
    this.menuTarget.classList.add("hidden")
  }

  async copy(event) {
    const thinking = event.params.thinking || false
    const toolDetails = event.params.toolDetails || false

    const url = new URL(this.urlValue, window.location.origin)
    if (thinking) url.searchParams.set("thinking", "1")
    if (toolDetails) url.searchParams.set("tool_details", "1")

    try {
      const response = await fetch(url)
      const text = await response.text()
      await navigator.clipboard.writeText(text)

      this.labelTarget.textContent = "Copied!"
      this.element.classList.add("copied")
      this.close()

      setTimeout(() => {
        this.labelTarget.textContent = "Copy as Markdown"
        this.element.classList.remove("copied")
      }, 2000)
    } catch {
      this.labelTarget.textContent = "Failed"
      setTimeout(() => {
        this.labelTarget.textContent = "Copy as Markdown"
      }, 2000)
    }
  }
}
