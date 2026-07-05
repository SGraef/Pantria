# frozen_string_literal: true
# typed: false

module Garden
  # Registry of official German WMS geodata sources for the garden map: the
  # nationwide basemap.de base layer plus per-Bundesland aerial orthophotos
  # (DOP20) and cadastral parcel maps (ALKIS). Only endpoints whose
  # GetCapabilities were actually verified (EPSG:3857 support, layer name,
  # license) are listed; households in other states pick "custom" and enter
  # their state's WMS themselves. Adding a state is a one-entry change here.
  #
  # All listed services are open data; the attribution strings are rendered in
  # the map's attribution control as the licenses require.
  module MapSources
    CUSTOM = "custom"

    # Nationwide official base map (AdV/BKG), CC BY 4.0.
    BASEMAP = {
      url:         "https://sgx.geodatenzentrum.de/wms_basemapde",
      layer:       "de_basemapde_web_raster_farbe",
      attribution: "&copy; GeoBasis-DE / BKG CC BY 4.0"
    }.freeze

    STATES = {
      "ni" => {
        name:    "Niedersachsen",
        dop:     {
          url:         "https://opendata.lgln.niedersachsen.de/doorman/noauth/dop_wms",
          layer:       "ni_dop20",
          attribution: "&copy; LGLN, CC BY 4.0"
        },
        alkis:   {
          url:         "https://opendata.lgln.niedersachsen.de/doorman/noauth/alkis_wms",
          layer:       "ALKIS",
          attribution: "&copy; LGLN, CC BY 4.0"
        },
        # Vector Flurstücke for the parcel lookup (WFS 2.0, GML out, see
        # Garden::ParcelLookup for the query mechanics -- verified live).
        parcels: {
          url:       "https://opendata.lgln.niedersachsen.de/doorman/noauth/alkis_wfs_einfach",
          type_name: "ave:Flurstueck"
        }
      },
      "nw" => {
        name:  "Nordrhein-Westfalen",
        dop:   {
          url:         "https://www.wms.nrw.de/geobasis/wms_nw_dop",
          layer:       "nw_dop_rgb",
          attribution: "&copy; Geobasis NRW, dl-de/zero-2-0"
        },
        alkis: nil # NRW ALKIS WMS not verified yet
      }
    }.freeze

    # Registry Bundesland codes (without "custom").
    KEYS = STATES.keys.freeze

    class << self
      # @return [Hash, nil]
      def fetch(code)
        STATES[code]
      end

      # Options for the settings <select>: registered states plus "custom".
      # @return [Array<Array(String, String)>]
      def options_for_select
        STATES.map { |code, state| [state[:name], code] } +
          [[I18n.t("garden_map.settings.custom_option"), CUSTOM]]
      end

      # Resolved layer set for the Stimulus map controller: always the
      # basemap, plus dop/alkis from the registry or the setting's custom
      # fields. Layers the household has no source for come back nil and the
      # map hides their toggles.
      # @param setting [GardenMapSetting]
      # @return [Hash{Symbol=>Hash,nil}]
      def client_config(setting)
        if setting.bundesland == CUSTOM
          { basemap: BASEMAP,
            dop:     custom_layer(setting.custom_dop_url, setting.custom_dop_layer),
            alkis:   custom_layer(setting.custom_alkis_url, setting.custom_alkis_layer) }
        else
          state = fetch(setting.bundesland) || {}
          { basemap: BASEMAP, dop: state[:dop], alkis: state[:alkis] }
        end
      end

      # The Flurstück vector source for the parcel lookup, when the
      # household's Bundesland ships one (nil for custom/unregistered).
      # @param setting [GardenMapSetting]
      # @return [Hash, nil]
      def parcel_source(setting)
        fetch(setting.bundesland)&.dig(:parcels)
      end

      private

      def custom_layer(url, layer)
        return nil if url.blank? || layer.blank?

        { url: url, layer: layer, attribution: nil }
      end
    end
  end
end
