import { Controller } from "@hotwired/stimulus"

// Garden map: official WMS layers (basemap.de base, per-Bundesland DOP20
// aerial imagery + ALKIS cadastral parcels, see Garden::MapSources) with the
// household's beds as polygons. Beds are traced by clicking vertices on the
// map; geometry is PATCHed to the per-bed endpoint and the server-computed
// area comes back in the response. Leaflet is lazy-imported so only this
// page downloads it.
//
// The live area readout mirrors Garden::Geometry (equirectangular projection
// around the mean latitude + shoelace); the stored value is the server's.
const EARTH_RADIUS_M = 6378137.0

const BED_COLORS = ["#c97455", "#5b8c5a", "#5a7d8c", "#8c5a7d", "#8c7a5a", "#5a5f8c"]

export default class extends Controller {
  static values = {
    config: Object, // { basemap:, dop:, alkis: } url/layer/attribution each
    center: Array,
    zoom: Number,
    beds: Array,
    token: String,
    focusBedId: Number
  }

  static targets = ["map", "readout", "dopToggle", "alkisToggle", "swatch",
                    "bedArea", "drawControls", "centerLat", "centerLng", "zoom"]

  async connect() {
    this.L = await import("leaflet")
    if (!this.hasMapTarget) return // page changed while leaflet loaded

    this.beds = new Map(this.bedsValue.map((bed) => [bed.id, { ...bed }]))
    this.polygons = new Map()
    this.drawing = null

    this.initMap()
    this.renderBeds()
    this.paintSwatches()
    this.focusInitialBed()
  }

  disconnect() {
    this.map?.remove()
    this.map = null
  }

  initMap() {
    const L = this.L
    this.map = L.map(this.mapTarget, { zoomControl: true })
    this.map.setView(this.centerValue, this.zoomValue)

    const { basemap, dop, alkis } = this.configValue
    L.tileLayer.wms(basemap.url, {
      layers: basemap.layer, format: "image/png", attribution: basemap.attribution || ""
    }).addTo(this.map)

    this.dopLayer = dop && L.tileLayer.wms(dop.url, {
      layers: dop.layer, format: "image/jpeg", attribution: dop.attribution || ""
    })
    this.alkisLayer = alkis && L.tileLayer.wms(alkis.url, {
      layers: alkis.layer, format: "image/png", transparent: true, attribution: alkis.attribution || ""
    })

    // DOP on by default (the point of the map is the aerial view); parcels
    // opt-in. Toggles for layers the Bundesland has no source for are hidden.
    this.setupToggle(this.dopToggleTarget, this.dopLayer, true)
    this.setupToggle(this.alkisToggleTarget, this.alkisLayer, false)

    this.map.on("click", (e) => this.mapClicked(e))
    this.map.on("moveend zoomend", () => this.viewportChanged())
  }

  setupToggle(input, layer, initiallyOn) {
    if (!layer) {
      input.closest("label").hidden = true
      return
    }
    input.checked = initiallyOn
    if (initiallyOn) layer.addTo(this.map)
  }

  toggleDop() { this.applyToggle(this.dopToggleTarget, this.dopLayer) }
  toggleAlkis() { this.applyToggle(this.alkisToggleTarget, this.alkisLayer) }

  applyToggle(input, layer) {
    if (!layer) return
    if (input.checked) layer.addTo(this.map)
    else layer.remove()
  }

  // Mirror the map viewport into the settings form so an admin's "save"
  // persists where the map was left.
  viewportChanged() {
    if (!this.hasCenterLatTarget) return
    const center = this.map.getCenter()
    this.centerLatTarget.value = center.lat.toFixed(7)
    this.centerLngTarget.value = center.lng.toFixed(7)
    this.zoomTarget.value = this.map.getZoom()
  }

  // -- bed polygons ---------------------------------------------------------

  renderBeds() {
    this.polygons.forEach((polygon) => polygon.remove())
    this.polygons.clear()
    this.beds.forEach((bed) => {
      if (!bed.boundary || bed.boundary.length < 3) return
      const polygon = this.L.polygon(bed.boundary.map((p) => [p.lat, p.lng]), {
        color: this.bedColor(bed.id), weight: 2, fillOpacity: 0.25
      }).addTo(this.map)
      polygon.bindTooltip(bed.name, { permanent: true, direction: "center", className: "garden-map-label" })
      polygon.bindPopup(this.popupContent(bed))
      this.polygons.set(bed.id, polygon)
    })
  }

  popupContent(bed) {
    const root = document.createElement("div")
    const link = document.createElement("a")
    link.href = bed.url
    link.textContent = bed.name
    const title = document.createElement("strong")
    title.appendChild(link)
    root.appendChild(title)
    if (bed.plantings.length) {
      const plantings = document.createElement("div")
      plantings.textContent = bed.plantings.join(", ")
      root.appendChild(plantings)
    }
    if (bed.areaSqm) {
      const area = document.createElement("div")
      area.textContent = this.areaLabel(bed.areaSqm)
      root.appendChild(area)
    }
    return root
  }

  bedColor(bedId) {
    const index = [...this.beds.keys()].indexOf(bedId)
    return BED_COLORS[index % BED_COLORS.length]
  }

  paintSwatches() {
    this.swatchTargets.forEach((el) => {
      el.style.background = this.bedColor(Number(el.dataset.bedId))
    })
  }

  focusInitialBed() {
    const polygon = this.polygons.get(this.focusBedIdValue)
    if (!polygon) return
    this.map.fitBounds(polygon.getBounds(), { maxZoom: 19 })
    polygon.openPopup()
  }

  // -- drawing --------------------------------------------------------------

  startDraw(event) {
    this.cancelDraw()
    const bedId = Number(event.currentTarget.dataset.bedId)
    this.drawing = { bedId, points: [], markers: [], preview: null }
    this.polygons.get(bedId)?.setStyle({ opacity: 0.3, fillOpacity: 0.05 })
    this.mapTarget.classList.add("garden-map-drawing")
    this.drawControlsTarget.hidden = false
    this.setReadout(this.element.dataset.i18nDrawHint)
  }

  mapClicked(e) {
    if (!this.drawing) return
    const point = { lat: e.latlng.lat, lng: e.latlng.lng }
    this.drawing.points.push(point)
    this.drawing.markers.push(
      this.L.circleMarker(e.latlng, { radius: 5, color: "#c97455", fillOpacity: 1 }).addTo(this.map)
    )
    this.updatePreview()
  }

  updatePreview() {
    const { points } = this.drawing
    this.drawing.preview?.remove()
    this.drawing.preview = this.L.polyline(
      points.concat(points.length > 2 ? [points[0]] : []).map((p) => [p.lat, p.lng]),
      { color: "#c97455", dashArray: "6 4", weight: 2 }
    ).addTo(this.map)
    if (points.length >= 3) this.setReadout(this.areaLabel(polygonAreaSqm(points)))
  }

  finishDraw() {
    if (!this.drawing) return
    const { bedId, points } = this.drawing
    if (points.length < 3) {
      this.setReadout(this.element.dataset.i18nDrawNeedPoints)
      return
    }
    this.saveGeometry(bedId, { boundary: points }).then((saved) => {
      if (saved) this.cancelDraw()
    })
  }

  cancelDraw() {
    if (!this.drawing) return
    this.drawing.markers.forEach((m) => m.remove())
    this.drawing.preview?.remove()
    this.polygons.get(this.drawing.bedId)?.setStyle({ opacity: 1, fillOpacity: 0.25 })
    this.drawing = null
    this.mapTarget.classList.remove("garden-map-drawing")
    this.drawControlsTarget.hidden = true
    this.setReadout("")
  }

  clearBoundary(event) {
    const bedId = Number(event.currentTarget.dataset.bedId)
    this.saveGeometry(bedId, { boundary: [] })
  }

  // -- persistence ----------------------------------------------------------

  async saveGeometry(bedId, attributes) {
    const bed = this.beds.get(bedId)
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
      if ("boundary" in attributes) bed.boundary = attributes.boundary
      bed.areaSqm = data.area_sqm
      this.renderBeds()
      this.updateBedArea(bedId, data.area_sqm)
      return true
    } catch {
      this.setReadout(this.element.dataset.i18nSaveFailed)
      return false
    }
  }

  updateBedArea(bedId, areaSqm) {
    const el = this.bedAreaTargets.find((t) => Number(t.dataset.bedId) === bedId)
    if (el) el.textContent = areaSqm ? this.areaLabel(areaSqm) : ""
  }

  // -- helpers --------------------------------------------------------------

  areaLabel(areaSqm) {
    return this.element.dataset.i18nAreaLabel.replace("%{area}", formatArea(areaSqm))
  }

  setReadout(text) {
    if (this.hasReadoutTarget) this.readoutTarget.textContent = text || ""
  }
}

// Shoelace on an equirectangular projection around the ring's mean latitude —
// the JS mirror of Garden::Geometry.polygon_area_sqm.
function polygonAreaSqm(ring) {
  if (ring.length < 3) return 0
  const lat0 = ring.reduce((sum, p) => sum + p.lat, 0) / ring.length
  const cos0 = Math.cos((lat0 * Math.PI) / 180)
  const pts = ring.map((p) => [
    EARTH_RADIUS_M * ((p.lng * Math.PI) / 180) * cos0,
    EARTH_RADIUS_M * ((p.lat * Math.PI) / 180)
  ])
  let sum = 0
  for (let i = 0; i < pts.length; i++) {
    const [x1, y1] = pts[i]
    const [x2, y2] = pts[(i + 1) % pts.length]
    sum += x1 * y2 - x2 * y1
  }
  return Math.abs(sum) / 2
}

function formatArea(areaSqm) {
  return new Intl.NumberFormat(document.documentElement.lang || "de", {
    minimumFractionDigits: 1, maximumFractionDigits: 1
  }).format(areaSqm)
}
