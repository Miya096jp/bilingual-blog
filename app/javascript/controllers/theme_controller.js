import { Controller } from "@hotwired/stimulus";

export default class extends Controller {
  changeTheme(event) {
    const color = event.target.value;
    document.documentElement.className = `${color}-theme`;
  }
}
