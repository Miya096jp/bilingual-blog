import { Controller } from "@hotwired/stimulus";

export default class extends Controller {
  static targets = ["modal"];

  connect() {
    console.log("✅ AuthModal controller connected!");
  }

  showModal(e) {
    if (e) e.preventDefault()
    this.modalTarget.classList.remove("hidden");
  }

  closeModal(e) {
    if (e) e.preventDefault()
    this.modalTarget.classList.add("hidden");
    // this.resetForm();
  }

  closeOnOutsideClick(event) {
    if (event.target === this.modalTarget) {
      this.closeModal();
    }
  }

  stopPropagation(event) {
    event.stopPropagation();
  }

  // ESCキーでも閉じられるようにする
  closeOnEscape(event) {
    if (event.key === "Escape") {
      this.closeModal();
    }
  }

  resetForm() {
    setTimeout(() => {
      const errorMessage = this.modalTarget.querySelector('[role="alert"]');
      if (errorMessage) errorMessage.remove();

      const form = this.modalTarget.querySelector("form");
      if (form) form.reset();
    }, 200);
  }
}
