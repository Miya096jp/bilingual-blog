import { Controller } from "@hotwired/stimulus";

export default class extends Controller {
  static targets = ["modal", "signinForm", "signupForm", "title"];

  connect() {
    console.log("✅ AuthModal controller connected!");
  }

  showModal() {
    this.modalTarget.classList.remove("hidden");
    this.switchToSignin(); // デフォルトでサインインフォームを表示
  }

  closeModal() {
    this.modalTarget.classList.add("hidden");
  }

  switchToSignin() {
    this.signinFormTarget.classList.remove("hidden");
    this.signupFormTarget.classList.add("hidden");
    this.titleTarget.textContent = "Sign in to your account";
  }

  switchToSignup() {
    this.signinFormTarget.classList.add("hidden");
    this.signupFormTarget.classList.remove("hidden");
    this.titleTarget.textContent = "Create your account";
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
}
