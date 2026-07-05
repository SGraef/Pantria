import { Controller } from "@hotwired/stimulus"

// The to-scale garden planner: beds are rectangles (width_m x length_m, from
// the inputs in the table below the canvas) on an SVG with a 1 m grid.
// When the Grundstück has been captured on the garden map, its outline is
// projected to local meters and drawn as the backdrop, so beds are arranged
// inside the real property shape. Dragging a bed PATCHes its position
// through the same per-bed geometry endpoint the dimension inputs use.
//
// The SVG viewBox is in meters (1 unit = 1 m), so all sizes/positions are
// real-world values and scaling is just viewport math.
const EARTH_RADIUS_M = 6378137.0
const MARGIN_M = 1
const MIN_CANVAS_M = 10
const SNAP_M = 0.1

export default class extends Controller {
  static values = {
    beds: Array,
    property: Array, // Grundstück ring [{lat, lng}, ...]; may be empty
    token: String
  }

  static targets = ["svg", "width", "length", "bedArea"]

  connect() {
    this.beds = new Map(this.bedsValue.map((bed) => [bed.id, { ...bed }]))
    this.propertyMeters = projectToMeters(this.propertyValue)
    this.dragging = null
    this.render()
  }

  // -- rendering ------------------------------------------------------------

  render() {
    const svg = this.svgTarget
    svg.textContent = ""
    const sized = this.sizedBeds()

    const extent = sized.reduce(
      (max, bed) => ({
        x: Math.max(max.x, (bed.posXM || 0) + bed.widthM),
        y: Math.max(max.y, (bed.posYM || 0) + bed.lengthM)
      }),
      this.propertyExtent() || { x: MIN_CANVAS_M, y: MIN_CANVAS_M / 2 }
    )
    const w = extent.x + MARGIN_M * 2
    const h = extent.y + MARGIN_M * 2
    svg.setAttribute("viewBox", `${-MARGIN_M} ${-MARGIN_M} ${w} ${h}`)
    svg.style.aspectRatio = `${w} / ${h}`

    this.drawGrid(svg, w, h)
    this.drawProperty(svg)
    sized.forEach((bed) => this.drawBed(svg, bed))
  }

  propertyExtent() {
    if (!this.propertyMeters) return null
    return {
      x: Math.max(...this.propertyMeters.map(([x]) => x)),
      y: Math.max(...this.propertyMeters.map(([, y]) => y))
    }
  }

  sizedBeds() {
    return [...this.beds.values()].filter((bed) => bed.widthM && bed.lengthM)
  }

  drawGrid(svg, w, h) {
    const grid = this.el("g", { class: "grid" })
    for (let x = 0; x <= Math.ceil(w - MARGIN_M); x++) {
      grid.appendChild(this.el("line", { x1: x, y1: -MARGIN_M, x2: x, y2: h - MARGIN_M }))
    }
    for (let y = 0; y <= Math.ceil(h - MARGIN_M); y++) {
      grid.appendChild(this.el("line", { x1: -MARGIN_M, y1: y, x2: w - MARGIN_M, y2: y }))
    }
    svg.appendChild(grid)
  }

  drawProperty(svg) {
    if (!this.propertyMeters) return
    const d = `${this.propertyMeters
      .map(([x, y], i) => `${i === 0 ? "M" : "L"}${x.toFixed(2)} ${y.toFixed(2)}`)
      .join(" ")} Z`
    svg.appendChild(this.el("path", { class: "property", d }))
  }

  drawBed(svg, bed) {
    const x = bed.posXM || 0
    const y = bed.posYM || 0
    const group = this.el("g", { class: "bed", "data-bed-id": bed.id })
    group.appendChild(this.el("rect", { x, y, width: bed.widthM, height: bed.lengthM, rx: 0.1 }))

    const label = this.el("text", {
      x: x + bed.widthM / 2, y: y + bed.lengthM / 2,
      "text-anchor": "middle", "dominant-baseline": "middle",
      "font-size": Math.min(0.5, bed.lengthM / 2)
    })
    label.textContent = bed.name
    group.appendChild(label)

    group.addEventListener("pointerdown", (e) => this.dragStart(e, bed))
    svg.appendChild(group)
  }

  el(tag, attrs) {
    const node = document.createElementNS("http://www.w3.org/2000/svg", tag)
    Object.entries(attrs).forEach(([key, value]) => node.setAttribute(key, value))
    return node
  }

  // -- dragging (pointer events, coordinates in SVG user units = meters) ----

  dragStart(event, bed) {
    event.preventDefault()
    const point = this.svgPoint(event)
    this.dragging = {
      bed,
      offsetX: point.x - (bed.posXM || 0),
      offsetY: point.y - (bed.posYM || 0),
      moved: false
    }
    this.svgTarget.setPointerCapture(event.pointerId)
    this.moveHandler = (e) => this.dragMove(e)
    this.upHandler = (e) => this.dragEnd(e)
    this.svgTarget.addEventListener("pointermove", this.moveHandler)
    this.svgTarget.addEventListener("pointerup", this.upHandler, { once: true })
  }

  dragMove(event) {
    if (!this.dragging) return
    const { bed, offsetX, offsetY } = this.dragging
    const point = this.svgPoint(event)
    bed.posXM = Math.max(0, snap(point.x - offsetX))
    bed.posYM = Math.max(0, snap(point.y - offsetY))
    this.dragging.moved = true
    this.render()
  }

  dragEnd(event) {
    this.svgTarget.removeEventListener("pointermove", this.moveHandler)
    const drag = this.dragging
    this.dragging = null
    if (drag?.moved) {
      this.save(drag.bed, { pos_x_m: drag.bed.posXM, pos_y_m: drag.bed.posYM })
    }
  }

  svgPoint(event) {
    const point = new DOMPoint(event.clientX, event.clientY)
    return point.matrixTransform(this.svgTarget.getScreenCTM().inverse())
  }

  // -- dimension inputs -----------------------------------------------------

  dimensionChanged(event) {
    const bedId = Number(event.currentTarget.dataset.bedId)
    const bed = this.beds.get(bedId)
    const width = this.inputValue(this.widthTargets, bedId)
    const length = this.inputValue(this.lengthTargets, bedId)
    if (!width || !length) return

    bed.widthM = width
    bed.lengthM = length
    this.render()
    this.save(bed, { width_m: width, length_m: length })
  }

  inputValue(targets, bedId) {
    const input = targets.find((t) => Number(t.dataset.bedId) === bedId)
    const value = parseFloat(input?.value)
    return Number.isFinite(value) && value > 0 ? value : null
  }

  // -- persistence ----------------------------------------------------------

  async save(bed, attributes) {
    try {
      const response = await fetch(bed.geometryUrl, {
        method: "PATCH",
        headers: {
          "Content-Type": "application/json",
          "X-CSRF-Token": this.tokenValue,
          "Accept": "application/json"
        },
        body: JSON.stringify({ garden_bed: attributes })
      })
      if (!response.ok) throw new Error(`HTTP ${response.status}`)
      const data = await response.json()
      this.updateBedArea(bed.id, data.area_sqm)
    } catch {
      alert(this.element.dataset.i18nSaveFailed)
    }
  }

  updateBedArea(bedId, areaSqm) {
    const el = this.bedAreaTargets.find((t) => Number(t.dataset.bedId) === bedId)
    if (!el || !areaSqm) return
    const formatted = new Intl.NumberFormat(document.documentElement.lang || "de", {
      minimumFractionDigits: 1, maximumFractionDigits: 1
    }).format(areaSqm)
    el.textContent = this.element.dataset.i18nAreaLabel.replace("%{area}", formatted)
  }
}

function snap(meters) {
  return Math.round(meters / SNAP_M) * SNAP_M
}

// Project a WGS84 ring to local meters (equirectangular around the mean
// latitude), normalized so the outline's bounding box starts at (0, 0).
// SVG y grows downward, so latitude is flipped (north = up).
function projectToMeters(ring) {
  if (!ring || ring.length < 3) return null
  const lat0 = ring.reduce((sum, p) => sum + p.lat, 0) / ring.length
  const cos0 = Math.cos((lat0 * Math.PI) / 180)
  const pts = ring.map((p) => [
    EARTH_RADIUS_M * ((p.lng * Math.PI) / 180) * cos0,
    -EARTH_RADIUS_M * ((p.lat * Math.PI) / 180)
  ])
  const minX = Math.min(...pts.map(([x]) => x))
  const minY = Math.min(...pts.map(([, y]) => y))
  return pts.map(([x, y]) => [x - minX, y - minY])
}
