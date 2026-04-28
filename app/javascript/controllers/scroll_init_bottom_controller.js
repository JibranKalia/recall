import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  connect() {
    if (window.location.hash) return
    requestAnimationFrame(() => {
      window.scrollTo({ top: document.body.scrollHeight, behavior: "instant" })
    })
  }
}
