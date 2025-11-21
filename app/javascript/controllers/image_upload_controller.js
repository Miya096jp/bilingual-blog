import { Controller } from "@hotwired/stimulus";

export default class extends Controller {
  static targets = ["textarea"];

  selectImage() {
    console.log("selectImage called!"); // ← 追加
    const input = document.createElement("input");
    input.type = "file";
    input.accept = "image/*";
    input.addEventListener("change", (e) => {
      const file = e.target.files[0];
      if (file) {
        this.uploadImage(file);
      }
    });
    input.click();
  }

  uploadImage(file) {
    console.log("uploadImage called with:", file);
    const formData = new FormData();
    formData.append("image", file);

    const locale = window.location.pathname.split("/")[1];
    const url = `/${locale}/admin/images`;

    fetch(url, {
      method: "POST",
      headers: {
        "X-CSRF-Token": document.querySelector("meta[name='csrf-token']")
          .content,
      },
      body: formData,
    })
      .then((response) => response.json())
      .then((data) => {
        console.log("Data received:", data);
        if (data.url) {
          this.insertImageMarkdown(data.url, file.name);
        }
      });
  }

  insertImageMarkdown(url, filename) {
    const textarea = this.textareaTarget;
    const cursorPos = textarea.selectionStart;
    const textBefore = textarea.value.substring(0, cursorPos);
    const textAfter = textarea.value.substring(cursorPos);
    const markdown = `![${filename}](${url})`;

    textarea.value = textBefore + markdown + textAfter;
    textarea.focus();
    textarea.setSelectionRange(
      cursorPos + markdown.length,
      cursorPos * markdown.length,
    );

    textarea.dispatchEvent(new Event("input"));
  }
}
