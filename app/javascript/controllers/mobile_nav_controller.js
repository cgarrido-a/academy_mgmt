import { Controller } from "@hotwired/stimulus"

// Abre y cierra el menú del navbar en pantallas chicas.
// En desktop el CSS ignora `is-open`, así que el estado no molesta.
export default class extends Controller {
  static targets = ["menu", "button"]

  toggle() {
    this.menuTarget.classList.toggle("is-open")
    this.#syncButton()
  }

  close() {
    this.menuTarget.classList.remove("is-open")
    this.#syncButton()
  }

  // Cerrar al tocar un link: Turbo no recarga el layout, el menú quedaría abierto.
  closeOnNavigation(event) {
    if (event.target.closest("a, button")) this.close()
  }

  #syncButton() {
    const open = this.menuTarget.classList.contains("is-open")
    if (this.hasButtonTarget) {
      this.buttonTarget.setAttribute("aria-expanded", open ? "true" : "false")
      this.buttonTarget.setAttribute("aria-label", open ? "Cerrar menú" : "Abrir menú")
      this.buttonTarget.textContent = open ? "✕" : "☰"
    }
  }
}
