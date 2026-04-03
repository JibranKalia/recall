import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["header", "stickyBar", "stickyTitle"]

  connect() {
    this.handleScroll = this.onScroll.bind(this)
    window.addEventListener("scroll", this.handleScroll, { passive: true })
    this.onScroll()
  }

  disconnect() {
    window.removeEventListener("scroll", this.handleScroll)
  }

  onScroll() {
    const headerBottom = this.headerTarget.getBoundingClientRect().bottom
    const pastHeader = headerBottom < 56 // nav height
    this.stickyBarTarget.classList.toggle("sticky-bar--scrolled", pastHeader)
    this.stickyTitleTarget.classList.toggle("hidden", !pastHeader)
  }
}
