// MVP版での提供見送り
// URLの設計改善・レイアウト崩れなどを優先


import { Controller } from "@hotwired/stimulus";

export default class extends Controller {
  static targets = ["modal", "form", "select", "localeInput"];
  static values = { url: String, locale: String };

  connect() {
    this.boundCloseOnEscape = this.closeOnEscape.bind(this);
    this.boundCloseOnOutsideClick = this.closeOnOutsideClick.bind(this);
    
    // モーダルを開いたときにlocaleをhiddenフィールドに設定
    if (this.hasLocaleInputTarget) {
      this.localeInputTarget.value = this.localeValue;
    }
  }

  showModal() {
    // モーダルを開く前にlocaleを設定
    if (this.hasLocaleInputTarget) {
      this.localeInputTarget.value = this.localeValue;
    }
    
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
    // localeはhiddenフィールドから自動的に送信される

    // デバッグ：送信されるデータを確認
    console.log("=== Category Modal Submit ===");
    console.log("Locale Value:", this.localeValue);
    console.log("Form Data:");
    for (let [key, value] of formData.entries()) {
      console.log(`  ${key}: ${value}`);
    }
    console.log("============================");


    const url = `${this.urlValue}?locale=${this.localeValue}`;

    try {
      const response = await fetch(url, {
        method: "POST",
        headers: {
          "X-CSRF-Token": document.querySelector('meta[name="csrf-token"]').content,
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
      alert("エラーが発生しました");
    }
  }
}
