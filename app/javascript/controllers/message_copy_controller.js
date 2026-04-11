import { Controller } from "@hotwired/stimulus"

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

function flashIcon(el, originalClass) {
  el.classList.remove(originalClass)
  el.classList.add("icon--check")

  setTimeout(() => {
    el.classList.remove("icon--check")
    el.classList.add(originalClass)
  }, 1500)
}

// Copies the text content of a message to the clipboard
export default class extends Controller {
  static targets = ["content", "icon", "linkIcon"]
  static values = { raw: String }

  async copy() {
    const text = this.hasRawValue && this.rawValue ? this.rawValue : this.contentTarget.innerText
    await copyText(text)
    flashIcon(this.iconTarget, "icon--copy")
  }

  async copyLink() {
    const url = `${window.location.origin}${window.location.pathname}#${this.element.id}`
    await copyText(url)
    flashIcon(this.linkIconTarget, "icon--link")
  }
}
