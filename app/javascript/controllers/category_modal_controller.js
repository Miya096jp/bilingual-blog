import { Controller } from "@hotwired/stimulus";

export default class extends Controller {
  static targets = ["modal", "form", "select"];
  static values = { url: String, locale: String };

  connect() {
    this.boundCloseOnEscape = this.closeOnEscape.bind(this);
    this.boundCloseOnOutsideClick = this.closeOnOutsideClick.bind(this);
  }

  showModal() {
    this.modalTarget.classList.remove("hidden");
    document.addEventListener("keydown", this.boundCloseOnEscape);
    document.addEventListener("click", this.boundCloseOnOutsideClick);
  }

  closeModal() {
    this.modalTarget.classList.add("hidden");
    document.removeEventListener("keydown", this.boundCloseOnEscape);
    document.removeEventListener("click", this.boundCloseOnOutsideClick);
    this.formTarget.reset();
  }

  closeOnEscape(event) {
    if (event.key === "Escape") {
      this.closeModal();
    }
  }

  closeOnOutsideClick(event) {
    if (event.target === this.modalTarget) {
      this.closeModal();
    }
  }

  async submitForm(event) {
    event.preventDefault();

    const formData = new FormData(this.formTarget);
    formData.append("locale", this.localeValue);

    try {
      const response = await fetch(this.urlValue, {
        method: "POST",
        headers: {
          "X-CSRF-Token": document.querySelector('meta[name="csrf-token"]')
            .content,
        },
        body: formData,
      });

      const data = await response.json();

      if (response.ok) {
        const option = new Option(data.category.name, data.category.id);
        this.selectTarget.add(option);
        this.selectTarget.value = data.category.id;
        this.closeModal();
      } else {
        alert(data.error || "カテゴリの作成に失敗しました");
      }
    } catch (error) {
      console.error("Error:", error);
      alert("エラーが発生した");
    }
  }
}
