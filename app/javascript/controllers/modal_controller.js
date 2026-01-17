import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["dialog"]

  // Action to open the modal
  open() {
    this.dialogTarget.showModal()
  }

  // Action to close the modal
  close() {
    this.dialogTarget.close()
  }

  // Optional: Close when clicking outside the modal content (backdrop)
  clickOutside(event) {
    if (event.target === this.dialogTarget) {
      this.close()
    }
  }
}
