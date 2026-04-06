import { Controller } from "@hotwired/stimulus"

const COPY_SVG = `<svg width="14" height="14" viewBox="0 0 16 16" fill="none" stroke="currentColor" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round"><rect x="5.5" y="5.5" width="8" height="8" rx="1.5"/><path d="M10.5 5.5V3a1.5 1.5 0 0 0-1.5-1.5H3A1.5 1.5 0 0 0 1.5 3v6A1.5 1.5 0 0 0 3 10.5h2.5"/></svg>`
const CHECK_SVG = `<svg width="14" height="14" viewBox="0 0 16 16" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M3 8.5l3.5 3.5 6.5-7"/></svg>`

function copyText(text) {
  if (navigator.clipboard?.writeText) {
    return navigator.clipboard.writeText(text)
  }
  // Fallback for non-HTTPS contexts
  const textarea = document.createElement("textarea")
  textarea.value = text
  textarea.style.position = "fixed"
  textarea.style.opacity = "0"
  document.body.appendChild(textarea)
  textarea.select()
  document.execCommand("copy")
  document.body.removeChild(textarea)
  return Promise.resolve()
}

// Copies the text content of a message to the clipboard
export default class extends Controller {
  static targets = ["content", "icon"]
  static values = { raw: String }

  async copy() {
    const text = this.hasRawValue && this.rawValue ? this.rawValue : this.contentTarget.innerText
    await copyText(text)

    const btn = this.element.querySelector(".msg-copy-btn")
    this.iconTarget.innerHTML = CHECK_SVG
    btn.classList.add("msg-copy-copied")

    setTimeout(() => {
      this.iconTarget.innerHTML = COPY_SVG
      btn.classList.remove("msg-copy-copied")
    }, 1500)
  }
}
