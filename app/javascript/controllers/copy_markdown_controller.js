import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["label", "menu"]
  static values = { url: String }

  toggle(event) {
    event.stopPropagation()
    this.menuTarget.classList.toggle("hidden")
  }

  close() {
    this.menuTarget.classList.add("hidden")
  }

  async copy(event) {
    event.stopPropagation()

    const thinking = event.params.thinking === true || event.params.thinking === "true"
    const toolDetails = event.params.toolDetails === true || event.params.toolDetails === "true"

    let url = this.urlValue
    const params = []
    if (thinking) params.push("thinking=1")
    if (toolDetails) params.push("tool_details=1")
    if (params.length) url += "?" + params.join("&")

    try {
      const token = document.querySelector('meta[name="csrf-token"]')?.content
      const response = await fetch(url, {
        headers: {
          "X-CSRF-Token": token,
          "Accept": "text/markdown"
        }
      })

      if (!response.ok) throw new Error(response.statusText)

      const text = await response.text()
      await this.#copyToClipboard(text)

      this.labelTarget.textContent = "Copied!"
      this.element.classList.add("copied")
      this.close()

      setTimeout(() => {
        this.labelTarget.textContent = "Copy as Markdown"
        this.element.classList.remove("copied")
      }, 2000)
    } catch (error) {
      console.error("Copy markdown failed:", error)
      this.labelTarget.textContent = "Failed"
      this.close()
      setTimeout(() => {
        this.labelTarget.textContent = "Copy as Markdown"
      }, 2000)
    }
  }

  async #copyToClipboard(text) {
    if (navigator.clipboard?.writeText) {
      return navigator.clipboard.writeText(text)
    }

    // Fallback for non-secure contexts (e.g. accessing dev via IP)
    const textarea = document.createElement("textarea")
    textarea.value = text
    textarea.style.position = "fixed"
    textarea.style.opacity = "0"
    document.body.appendChild(textarea)
    textarea.select()
    document.execCommand("copy")
    document.body.removeChild(textarea)
  }
}
