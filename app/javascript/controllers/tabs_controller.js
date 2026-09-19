import { Controller } from "@hotwired/stimulus";

export default class extends Controller {
  static targets = ["tab", "panel"];

  show(event) {
    const name = event.currentTarget.dataset.tabsName;

    this.tabTargets.forEach((tab) => {
      const selected = tab.dataset.tabsName === name;
      tab.setAttribute("aria-selected", selected);
      tab.tabIndex = selected ? 0 : -1;
    });

    this.panelTargets.forEach((panel) => {
      panel.hidden = panel.dataset.tabsName !== name;
    });
  }
}
