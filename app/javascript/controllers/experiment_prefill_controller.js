import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["session", "template", "systemPrompt", "prompt", "name"]

  connect() {
    // Prefill if session already selected (e.g. from URL param)
    if (this.sessionTarget.value && this.templateTarget.value) {
      this.prefill()
    }
  }

  prefill() {
    const sessionId = this.sessionTarget.value
    const template = this.templateTarget.value

    if (!sessionId || !template) return

    fetch(`/experiments/prefill?session_id=${sessionId}&template=${template}`)
      .then(r => r.json())
      .then(data => {
        this.systemPromptTarget.value = data.system_prompt || ""
        this.promptTarget.value = data.prompt || ""
        if (data.name && !this.nameTarget.value) {
          this.nameTarget.value = data.name
        }
      })
  }
}
