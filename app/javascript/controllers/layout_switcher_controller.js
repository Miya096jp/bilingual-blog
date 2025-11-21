import { Controller } from "@hotwired/stimulus";

export default class extends Controller {
  static targets = ["textArea", "preview", "originalPreview", "buttons"];
  static values = { currentMode: String, translationMode: Boolean };

  connect() {
    this.currentModeValue = "split";
    this.updateLayout();
  }

  get isTranslationPage() {
    return this.translationModeValue === true;
  }

  switchToSplit() {
    this.currentModeValue = "split";
    this.updateLayout();
  }

  switchToTextOnly() {
    this.currentModeValue = "text-only";
    this.updateLayout();
  }

  switchToPreviewOnly() {
    this.currentModeValue = "preview-only";
    this.updateLayout();
  }

  switchToOriginalPreview() {
    if (!this.isTranslationPage) return;
    this.currentModeValue = "original-preview";
    this.updateLayout();
  }

  updateLayout() {
    this.element.classList.remove(
      "mode-split",
      "mode-text-only",
      "mode-preview-only",
      "mode-original-preview",
    );
    this.element.classList.add(`mode-${this.currentModeValue}`);
    this.updateButtonStates();
  }

  updateButtonStates() {
    this.buttonsTarget.querySelectorAll("button").forEach((button) => {
      button.classList.toggle(
        "active",
        button.dataset.mode === this.currentModeValue,
      );
    });
  }
}
