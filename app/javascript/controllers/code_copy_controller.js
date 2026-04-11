import { Controller } from "@hotwired/stimulus"
import { copyText } from "utils/clipboard"

// Adds copy buttons to all <pre> code blocks within the element
export default class extends Controller {
  connect() {
    this.element.querySelectorAll("pre").forEach((pre) => {
      if (pre.querySelector(".code-copy-btn")) return
      const code = pre.querySelector("code")
      if (!code) return

      const btn = document.createElement("button")
      btn.className = "code-copy-btn"
      btn.textContent = "Copy"
      btn.addEventListener("click", () => this.copy(btn, code))
      pre.style.position = "relative"
      pre.appendChild(btn)
    })
  }

  copy(btn, code) {
    copyText(code.textContent).then(() => {
      btn.textContent = "Copied!"
      btn.classList.add("copied")
      setTimeout(() => {
        btn.textContent = "Copy"
        btn.classList.remove("copied")
      }, 2000)
    })
  }
}
