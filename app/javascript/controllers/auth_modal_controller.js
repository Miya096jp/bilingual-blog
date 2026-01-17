import { Controller } from "@hotwired/stimulus";

export default class extends Controller {
  static targets = ["modal"];

  showModal(e) {
    if (e) e.preventDefault();
    this.modalTarget.classList.remove("hidden");
  }

  closeModal(e) {
    if (e) e.preventDefault();
    this.modalTarget.classList.add("hidden");
  }

  closeOnEscape(event) {
    if (event.key === "Escape") {
      this.closeModal();
    }
  }

  resetForm() {
    const form = this.modalTarget.querySelector("form");
    if (form) form.reset();
    
    const errorMessages = this.modalTarget.querySelectorAll('[role="alert"], .error-message');
    errorMessages.forEach(el => el.remove());
  }
}
