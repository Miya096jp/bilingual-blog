import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["content"]

  connect() {
    const input = this.contentTarget.querySelector("textarea, input")
    if (input?.value.trim() !== "") {
      this.contentTarget.classList.remove("hidden")
    }
  }

  toggle(e) {
    e.preventDefault()
    this.contentTarget.classList.toggle("hidden")
  }

  hide(e) {
    if (this.element.contains(e.target)) return

    const form = this.element.closest("form")
    if (form?.contains(e.target)) return

    this.contentTarget.classList.add("hidden")
  }

}
