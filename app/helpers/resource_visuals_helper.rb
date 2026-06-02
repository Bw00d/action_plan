module ResourceVisualsHelper
  # Agency name (normalized) → CSS color. Add agencies here as you encounter
  # them. Unknown agencies fall back to a deterministic hash of the name so the
  # same agency always renders the same color.
  AGENCY_COLORS = {
    'USFS'    => '#2e7d32',  # Forest Service — green
    'BLM'     => '#b08800',  # Bureau of Land Management — gold
    'NPS'     => '#5d4037',  # Park Service — brown
    'BIA'     => '#bf360c',  # BIA — burnt orange
    'USFWS'   => '#00838f',  # Fish & Wildlife — teal
    'CAL FIRE'=> '#c62828',  # CAL FIRE — red
    'CALFIRE' => '#c62828',
    'STATE'   => '#1565c0',  # generic state — blue
    'COUNTY'  => '#6a1b9a',  # county/local — purple
    'CONTRACT'=> '#546e7a',  # contract — slate gray
  }.freeze

  FALLBACK_PALETTE = %w[
    #ad1457 #4527a0 #283593 #00695c #ef6c00 #4e342e #37474f
  ].freeze

  # icon: FA4 class string, or :svg_dozer for the inline bulldozer SVG.
  def resource_icon_descriptor(resource)
    case resource.category
    when 'CREW'
      { type: :fa, name: 'fa-users' }
    when 'OVERHEAD'
      { type: :fa, name: 'fa-user' }
    when 'AIRCRAFT'
      position = resource.position.to_s.downcase
      icon = position.include?('plane') || position.include?('tanker') ? 'fa-plane' : 'fa-helicopter'
      { type: :fa, name: icon }
    when 'EQUIPMENT'
      equipment_icon(resource.position.to_s.downcase)
    else
      { type: :fa, name: 'fa-question-circle' }
    end
  end

  def resource_icon_html(resource)
    descriptor = resource_icon_descriptor(resource)
    case descriptor[:type]
    when :fa
      content_tag(:i, '', class: "fa #{descriptor[:name]}")
    when :svg
      dozer_svg
    end
  end

  def resource_strip_color(resource)
    key = resource.agency.to_s.strip.upcase
    AGENCY_COLORS[key] || fallback_color(key)
  end

  private

  def equipment_icon(position)
    return { type: :svg, name: :dozer } if position.include?('dozer')
    return { type: :fa, name: 'fa-tint' } if position.include?('tender') || position.include?('water')
    return { type: :fa, name: 'fa-truck' } if position.include?('engine')
    { type: :fa, name: 'fa-truck' }
  end

  def fallback_color(key)
    return '#9e9e9e' if key.blank?
    FALLBACK_PALETTE[key.bytes.sum % FALLBACK_PALETTE.size]
  end

  def dozer_svg
    # Simple bulldozer silhouette — 16x16 viewBox, currentColor.
    raw <<~SVG
      <svg class="resource-icon-svg" viewBox="0 0 24 16" xmlns="http://www.w3.org/2000/svg" aria-hidden="true">
        <path fill="currentColor" d="M3 4h7l2 3h6v3h1v3H2v-3h1V4zm1 2v3h6V6H4zm-2 6a2 2 0 1 0 0 .001zm14 0a2 2 0 1 0 0 .001zM17 7h-3v3h5V7z"/>
      </svg>
    SVG
  end
end
