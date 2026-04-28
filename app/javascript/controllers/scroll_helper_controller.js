import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = { direction: String }

  connect() {
    this.handleScroll = this.toggleVisibility.bind(this)
    window.addEventListener("scroll", this.handleScroll, { passive: true })
    this.toggleVisibility()
  }

  disconnect() {
    window.removeEventListener("scroll", this.handleScroll)
  }

  toggleVisibility() {
    const hide = this.directionValue === "top"
      ? window.scrollY <= 200
      : (window.innerHeight + window.scrollY) >= (document.body.scrollHeight - 200)
    this.element.classList.toggle("hidden", hide)
  }

  scroll() {
    const top = this.directionValue === "top" ? 0 : document.body.scrollHeight
    window.scrollTo({ top, behavior: "smooth" })
  }
}
