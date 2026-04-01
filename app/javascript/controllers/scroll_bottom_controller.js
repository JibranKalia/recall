import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  connect() {
    this.handleScroll = this.toggleVisibility.bind(this)
    window.addEventListener("scroll", this.handleScroll, { passive: true })
    this.toggleVisibility()
  }

  disconnect() {
    window.removeEventListener("scroll", this.handleScroll)
  }

  toggleVisibility() {
    const nearBottom = (window.innerHeight + window.scrollY) >= (document.body.scrollHeight - 200)
    this.element.classList.toggle("hidden", nearBottom)
  }

  scroll() {
    window.scrollTo({ top: document.body.scrollHeight, behavior: "smooth" })
  }
}
