# frozen_string_literal: true

# Beds are no longer traced on the geo map -- the map captures only the
# Grundstück; beds live in the to-scale planner. Salvage what we can from
# already-traced beds: derive width/length (and area) from the polygon's
# bounding box before dropping the column.
class RemoveBoundaryFromGardenBeds < ActiveRecord::Migration[8.0]
  EARTH_RADIUS_M = 6_378_137.0

  def up
    select_rows("SELECT id, boundary FROM garden_beds WHERE boundary IS NOT NULL").each do |id, json|
      ring = JSON.parse(json.to_s)
      next unless ring.is_a?(Array) && ring.length >= 3

      width, length = bbox_meters(ring)
      next if width.zero? || length.zero?

      execute sanitize_sql([
                             "UPDATE garden_beds SET width_m = COALESCE(width_m, ?), " \
                             "length_m = COALESCE(length_m, ?), area_sqm = ? WHERE id = ?",
                             width.round(2), length.round(2), (width * length).round(2), id
                           ])
    end

    remove_column :garden_beds, :boundary
  end

  def down
    add_column :garden_beds, :boundary, :json # traced polygons are not recoverable
  end

  private

  # Equirectangular bounding box of a lat/lng ring, in meters.
  def bbox_meters(ring)
    lats = ring.map { |p| p["lat"].to_f }
    lngs = ring.map { |p| p["lng"].to_f }
    cos0 = Math.cos((lats.sum / lats.length) * Math::PI / 180)
    width  = EARTH_RADIUS_M * ((lngs.max - lngs.min) * Math::PI / 180) * cos0
    length = EARTH_RADIUS_M * ((lats.max - lats.min) * Math::PI / 180)
    [width.abs, length.abs]
  end

  def sanitize_sql(array)
    ActiveRecord::Base.sanitize_sql_array(array)
  end
end
