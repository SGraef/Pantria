import { Controller } from "@hotwired/stimulus"

// Kanban drag & drop for the project board. Hand-rolled pointer-event drag
// (garden_lite precedent -- no drag library in the stack): grab a card by
// its grip, a fixed-position ghost follows the pointer, a dashed
// placeholder marks the insertion point (hit-testing column targets via
// elementFromPoint), and the drop PATCHes the move endpoint. The server
// answers with a turbo stream replacing the affected columns, so counts
// and ordering stay server-authoritative; without JS the per-card fallback
// form (hidden via .board--js) does the same move.
const DRAG_THRESHOLD_PX = 5

export default class extends Controller {
  static values = { token: String }
  static targets = ["column"]

  connect() {
    this.element.classList.add("board--js")
    this.drag = null
  }

  disconnect() {
    this.cancelDrag()
  }

  dragStart(event) {
    if (event.button !== undefined && event.button !== 0) return
    const card = event.target.closest(".board-card")
    if (!card) return

    event.preventDefault()
    this.drag = {
      card,
      pointerId: event.pointerId,
      startX: event.clientX,
      startY: event.clientY,
      offsetX: event.clientX - card.getBoundingClientRect().left,
      offsetY: event.clientY - card.getBoundingClientRect().top,
      started: false,
      ghost: null,
      placeholder: null
    }
    this.moveHandler = (e) => this.dragMove(e)
    this.upHandler = (e) => this.dragEnd(e)
    window.addEventListener("pointermove", this.moveHandler)
    window.addEventListener("pointerup", this.upHandler, { once: true })
    window.addEventListener("pointercancel", this.upHandler, { once: true })
  }

  dragMove(event) {
    const drag = this.drag
    if (!drag) return

    if (!drag.started) {
      const moved = Math.hypot(event.clientX - drag.startX, event.clientY - drag.startY)
      if (moved < DRAG_THRESHOLD_PX) return
      this.beginDrag(drag)
    }

    drag.ghost.style.left = `${event.clientX - drag.offsetX}px`
    drag.ghost.style.top = `${event.clientY - drag.offsetY}px`
    this.positionPlaceholder(event.clientX, event.clientY)
  }

  beginDrag(drag) {
    drag.started = true
    const rect = drag.card.getBoundingClientRect()

    drag.ghost = drag.card.cloneNode(true)
    drag.ghost.classList.add("board-card-ghost")
    drag.ghost.style.width = `${rect.width}px`
    document.body.appendChild(drag.ghost)

    drag.placeholder = document.createElement("div")
    drag.placeholder.className = "board-card-placeholder"
    drag.placeholder.style.minHeight = `${rect.height}px`
    drag.card.after(drag.placeholder)
    drag.card.classList.add("board-card--dragging")
  }

  // Place the placeholder in the column under the pointer, before the first
  // card whose vertical midpoint lies below it.
  positionPlaceholder(x, y) {
    const drag = this.drag
    const under = document.elementFromPoint(x, y)
    const column = under?.closest('[data-board-target="column"]')
    if (!column) return

    const cards = [...column.querySelectorAll(".board-card")]
      .filter((c) => c !== drag.card)
    const next = cards.find((c) => {
      const rect = c.getBoundingClientRect()
      return y < rect.top + rect.height / 2
    })
    if (next) column.insertBefore(drag.placeholder, next)
    else column.appendChild(drag.placeholder)
  }

  dragEnd(event) {
    const drag = this.drag
    window.removeEventListener("pointermove", this.moveHandler)
    this.drag = null
    if (!drag) return
    if (!drag.started) return // plain click -- let the link do its thing

    const column = drag.placeholder.closest('[data-board-target="column"]')
    const statusId = column?.dataset.statusId
    const index = column &&
      [...column.querySelectorAll(".board-card, .board-card-placeholder")]
        .filter((el) => el !== drag.card)
        .indexOf(drag.placeholder)

    // Optimistic move; the turbo stream re-render corrects if needed.
    if (column) drag.placeholder.replaceWith(drag.card)
    else drag.placeholder.remove()
    drag.card.classList.remove("board-card--dragging")
    drag.ghost.remove()

    if (statusId != null && index != null && index >= 0) {
      this.persist(drag.card, statusId, index)
    }
  }

  cancelDrag() {
    const drag = this.drag
    if (!drag) return
    window.removeEventListener("pointermove", this.moveHandler)
    drag.ghost?.remove()
    drag.placeholder?.remove()
    drag.card.classList.remove("board-card--dragging")
    this.drag = null
  }

  async persist(card, statusId, index) {
    try {
      const response = await fetch(card.dataset.moveUrl, {
        method: "PATCH",
        headers: {
          "Content-Type": "application/json",
          "X-CSRF-Token": this.tokenValue,
          "Accept": "text/vnd.turbo-stream.html"
        },
        body: JSON.stringify({ project: { project_status_id: statusId, position: index } })
      })
      if (!response.ok) throw new Error(`HTTP ${response.status}`)
      window.Turbo.renderStreamMessage(await response.text())
    } catch {
      window.location.reload() // resync with the server's truth
    }
  }
}
