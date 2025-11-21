import { Controller } from "@hotwired/stimulus";

export default class extends Controller {
  static targets = ["input", "preview", "titlePreview"];
  static values = { url: String };

  connect() {
    this.timeout = null;
    this.fetchPreview();
    this.updateTitlePreview();
    this.adjustHeight(this.inputTarget);
  }

  preview() {
    this.adjustHeight(this.inputTarget);
    this.updateTitlePreview();
    console.log("preview method called");
    clearTimeout(this.timeout);
    this.timeout = setTimeout(() => {
      this.fetchPreview();
    }, 50);
  }

  updateTitlePreview() {
    const title = document.querySelector('[data-field="title"]').value || "";
    this.titlePreviewTarget.innerHTML = `<h1>${title || "title"}</h1>`;
  }

  fetchPreview() {
    const content = this.inputTarget.value;

    console.log("=== プレビューデバッグ ===");
    console.log("URL:", this.urlValue);
    console.log("Content:", content);
    console.log("Content length:", content.length);

    if (content.trim() === "") {
      this.previewTarget.innerHTML = "<p>プレビューがここに表示されます</p>";
      return;
    }

    fetch(this.urlValue, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        "X-CSRF-Token": document.querySelector('meta[name="csrf-token"]')
          .content,
      },
      body: JSON.stringify({ content: content }),
    })
      .then((response) => {
        console.log("Response status:", response.status);
        return response.json();
      })
      .then((data) => {
        console.log("Response data:", data);
        this.previewTarget.innerHTML = data.html;
      })
      .catch((error) => {
        console.error("プレビューエラー:", error);
        this.previewTarget.innerHTML =
          "<p>プレビューの読み込みでエラーが発生しました</p>";
      });
  }

  adjustHeight(element) {
    element.style.height = "auto";
    const maxHeight = window.innerHeight * 0.8;
    element.style.height = Math.min(element.scrollHeight, maxHeight) + "px";
  }
}
