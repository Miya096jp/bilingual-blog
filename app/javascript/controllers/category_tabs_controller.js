import { Controller } from "@hotwired/stimulus";

export default class extends Controller {
  static targets = ["content", "button"];

  connect() {
    this.showTab("ja");
  }

  switchTab(event) {
    const targetTab = event.currentTarget.dataset.target;
    this.showTab(targetTab);
  }

  showTab(tab) {
    this.buttonTargets.forEach((button) => {
      button.classList.remove("active");
    });

    this.contentTargets.forEach((content) => {
      content.classList.remove("active");
    });

    const activeButton = this.buttonTargets.find(
      (button) => button.dataset.target === tab,
    );
    const activeContent = this.contentTargets.find(
      (content) => content.dataset.tab === tab,
    );

    activeButton?.classList.add("active");
    activeContent?.classList.add("active");
  }
}
