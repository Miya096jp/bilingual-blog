import { Controller } from "@hotwired/stimulus";

export default class extends Controller {
  static targets = ["modal"];
  static values = { signInUrl: String };

  showModal(e) {
    if (e) e.preventDefault();
    this.modalTarget.classList.remove("hidden");
  }

  closeModal(e) {
    if (e) e.preventDefault();
    this.modalTarget.classList.add("hidden");

    this.resetForm();

    const frame = document.getElementById("auth_form_frame");
    if (frame) {
      frame.src = this.signInUrlValue;
    }
  }

  closeOnEscape(event) {
    if (event.key === "Escape") {
      this.closeModal();
    }
  }

  resetForm() {
    const form = this.modalTarget.querySelector("form");
    if (form) {
      form.reset();
    }

    const errorContainers = this.modalTarget.querySelectorAll('#error_explanation, .bg-red-50, [role="alert"]');
    errorContainers.forEach(el => el.remove());
  }
}
