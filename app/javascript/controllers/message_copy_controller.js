import { Controller } from "@hotwired/stimulus"
import { copyText } from "utils/clipboard"

function flashIcon(el, originalClass) {
  el.classList.remove(originalClass)
  el.classList.add("icon--check")

  setTimeout(() => {
    el.classList.remove("icon--check")
    el.classList.add(originalClass)
  }, 1500)
}

export default class extends Controller {
  static targets = ["content", "icon", "linkIcon"]
  static values = { raw: String }

  async copy() {
    const text = this.rawValue || this.contentTarget.innerText
    await copyText(text)
    flashIcon(this.iconTarget, "icon--copy")
  }

  async copyLink() {
    const url = `${window.location.origin}${window.location.pathname}#${this.element.id}`
    await copyText(url)
    flashIcon(this.linkIconTarget, "icon--link")
  }
}
