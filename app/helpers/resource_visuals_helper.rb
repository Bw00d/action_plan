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

  # Position-code overrides — always win over the category default so
  # specific codes like DOZ1, AMB2, UMOD render the right icon regardless
  # of how iSuite categorizes them. Keys matched case-insensitively.
  POSITION_ICON_OVERRIDES = [
    # [matcher, image filename in app/assets/images/]
    [->(code) { code.start_with?('AMB') },                      'ambo.svg'],
    [->(code) { code.start_with?('DOZ') || code.start_with?('DZR') || code.include?('DOZER') || code.start_with?('DZS')}, 'dozer.svg'],
    [->(code) { code.start_with?('EXC') || code.include?('EXCAVATOR') }, 'excavator.svg'],
    [->(code) { code.start_with?('HE2') || code.start_with?('HE3') }, 'helicopter.svg'],
    [->(code) { code.start_with?('HE1') }, 'heavy.svg'],
    [->(code) { code.start_with?('FEL') }, 'buncher.svg'],
    [->(code) { code.start_with?('SKD') }, 'skidder.svg'],
    [->(code) { code.start_with?('SKG') }, 'skidgen.svg'],
    [->(code) { code.start_with?('BHOE') }, 'backhoe.svg'],
    [->(code) { code.start_with?('VROL') }, 'roller.svg'],
    [->(code) { code.start_with?('CHP') || code.start_with?('CHSL') }, 'chipper.svg'],
    [->(code) { code.start_with?('ENG1') || code.start_with?('ENG2') || code.start_with?('EST2') || code.start_with?('EST1') }, 'eng1.svg'],
    [->(code) { code.start_with?('ENG3') || code.start_with?('EST3')}, 'eng3.svg'],
    [->(code) { code.start_with?('ENG6') || code.start_with?('ENG4') || code.start_with?('ENG5') || code.start_with?('ENG7')|| code.start_with?('EST6') }, 'eng6.svg'],
    [->(code) { code.start_with?('WTT') || code.start_with?('WTS') }, 'tender.svg'],
    [->(code) { code.start_with?('FUT') || code.start_with?('POT') || code.start_with?('GWT')}, 'fuel-tender.svg'],
    [->(code) { code.start_with?('LOW') }, 'lowboy.svg'],
    [->(code) { code.start_with?('GRD') }, 'grader.svg'],
    [->(code) { code.start_with?('DUMP') }, 'dump-truck.svg'],
    [->(code) { code.start_with?('BUCC') || code.start_with?('BUS') }, 'bus.svg'],
    [->(code) { code.start_with?('FORK') }, 'forklift.svg'],
    [->(code) { code.start_with?('PUP') }, 'pickup.svg'],
    [->(code) { code.start_with?('STK') }, 'stakeside.svg'],
    [->(code) { code.start_with?('MBM') }, 'boom-masticator.svg'],
    [->(code) { code.start_with?('SMM') }, 'skid-steer.svg'],
    [->(code) { code.start_with?('TBOT') }, 'boat.svg'],
    [->(code) { code.start_with?('LOGL') }, 'loader.svg'],
    [->(code) { code.start_with?('PACK') }, 'packer.svg'],
    [->(code) { code.start_with?('LOGT') }, 'logtruck.svg'],
    # [->(code) { code.start_with?('LOGT') }, 'harvester.svg'],
    [->(code) { code.start_with?('ARF') }, 'air-rescue.svg'],
    [->(code) { code.start_with?('UTV') || code.start_with?('ATV') || code.start_with?('VUTV') || code.start_with?('VATV') || code.start_with?('OHV') }, 'utv.svg'],
    [->(code) { code == 'UMOD' || code.start_with?('UAR') || code.include?('DRONE') },  'drone.svg']
  ].freeze

  # Descriptor is { type:, name: }. Types:
  #   :fa    → FontAwesome 4 class name
  #   :image → filename under app/assets/images/
  #   :svg   → inline SVG (legacy dozer_svg only)
  def resource_icon_descriptor(resource)
    code = resource.position.to_s.upcase.strip
    POSITION_ICON_OVERRIDES.each do |matcher, image|
      return { type: :image, name: image } if matcher.call(code)
    end

    case resource.category
    when 'CREW'
      { type: :fa, name: 'fa-users' }
    when 'OVERHEAD'
      { type: :fa, name: 'fa-user' }
    when 'AIRCRAFT'
      icon = code.include?('PLANE') || code.include?('TANKER') ? 'fa-plane' : 'fa-helicopter'
      { type: :fa, name: icon }
    when 'EQUIPMENT'
      # No FontAwesome fallback for equipment — if there's no specific
      # SVG override (dozer / excavator / tender / etc.), render nothing.
      # Generic engine trucks / miscellaneous kit stay iconless.
      nil
    else
      { type: :fa, name: 'fa-question-circle' }
    end
  end

  def resource_icon_html(resource)
    descriptor = resource_icon_descriptor(resource)
    return ''.html_safe unless descriptor
    case descriptor[:type]
    when :fa
      content_tag(:i, '', class: "fa #{descriptor[:name]}")
    when :image
      inline_svg_asset(descriptor[:name])
    when :svg
      dozer_svg
    end
  end

  # Reads an SVG from app/assets/images/, strips any hard-coded colors so
  # CSS `fill: currentColor` controls the color, and injects it inline.
  # Handles both hand-written SVGs (with inline `fill="…"`) and Illustrator
  # exports (which put fill/stroke in a <style> block referencing CSS
  # classes on the elements). Cached at the class level.
  def inline_svg_asset(filename)
    @@_svg_cache ||= {}
    @@_svg_cache[filename] ||= begin
      path = Rails.root.join('app', 'assets', 'images', filename)
      if File.exist?(path)
        svg = File.read(path)
        # 1. Before stripping the <style> block, harvest `fill: none` /
        #    `stroke: none` class rules and inline them as attrs on the
        #    matching elements. Otherwise intentionally-hollow shapes
        #    (windows, outlines) become solid when currentColor
        #    inheritance kicks in on step 5.
        svg = inline_none_rules(svg)
        # 2. Drop Illustrator's <style> block — its class-based color
        #    rules would keep fill/stroke pinned to specific hex values.
        svg = svg.gsub(/<style[^>]*>.*?<\/style>/m, '')
        # 3. Remove now-empty <defs> wrappers so the file stays clean.
        svg = svg.gsub(/<defs[^>]*>\s*<\/defs>/m, '')
        # 4. Strip fill/stroke attrs but keep `fill="none"` /
        #    `stroke="none"` so hollow shapes stay hollow.
        svg = svg.gsub(/\sfill="(?!none)[^"]*"/,   '')
        svg = svg.gsub(/\sstroke="(?!none)[^"]*"/, '')
        # 5. Force the root <svg> to inherit currentColor for both fill
        #    and stroke — children inherit unless they explicitly set it.
        svg = svg.sub(/<svg/,
                      '<svg class="resource-icon-svg" aria-hidden="true" ' \
                      'fill="currentColor" stroke="currentColor"')
        svg
      else
        ''
      end
    end
    @@_svg_cache[filename].html_safe
  end

  # Extract `.cls-N { fill: none }` / `.cls-N { stroke: none }` rules
  # from the <style> block and inline them as attributes on elements
  # that use those classes. Runs before the style block is stripped.
  def inline_none_rules(svg)
    style_match = svg.match(/<style[^>]*>(.*?)<\/style>/m)
    return svg unless style_match

    class_styles = Hash.new { |h, k| h[k] = {} }
    style_match[1].scan(/([^{}]+)\{([^{}]+)\}/m) do |selectors, declarations|
      classes = selectors.scan(/\.([\w-]+)/).flatten
      declarations.scan(/(fill|stroke)\s*:\s*none/i) do |prop|
        prop_name = prop.first.downcase
        classes.each { |c| class_styles[c][prop_name] = 'none' }
      end
    end
    return svg if class_styles.empty?

    svg.gsub(/<(\w+)((?:(?!\/?>).)*?)\bclass="([^"]+)"((?:(?!\/?>).)*?)(\/?)>/m) do
      tag, before, class_str, after, self_close = $1, $2, $3, $4, $5
      extras = ''
      class_str.split(/\s+/).each do |cls|
        (class_styles[cls] || {}).each do |prop, val|
          extras += " #{prop}=\"#{val}\"" unless (before + after).include?(%(#{prop}=))
        end
      end
      "<#{tag}#{before} class=\"#{class_str}\"#{after}#{extras}#{self_close}>"
    end
  end

  # Standard ICS 219 T-card color scheme, keyed by position code or
  # falling back to the resource category. Returns a hash with :bg
  # (strip background) and :fg (text + icon color) so light fills
  # (yellow, pink, white, tan, lavender, light blue, light purple)
  # still have readable text.
  POSITION_COLOR_BUCKETS = {
    # 219-2 Crews — green
    crew: %w[SMOD FMOD CS12 CS1I CS2A CS2I CST1 CST2 CSTA CRW1 CRW2 CRWA CRWC CRWK CRWT],
    # 219-3 Helicopters — rose/salmon
    helicopter: %w[HE1R HE1S HE2R HE2S HE3R HE3S],
    # 219-4 Engines — yellow
    engine: %w[EN12 EN36 ENG1 ENG2 ENG3 ENG4 ENG5 ENG6 ENG7 ENGA ES36 EST1 EST2 EST3 EST4 EST5 EST6 EST7 ESTA],
    # 219-5 Dozers — gray
    dozer: %w[DZR1 DZR2 DZR3 DZR4 DZRA DZS1 DZS2 DZS3 DZS4 DZSA],
    # 219-6 Tractor/Plows — tan
    tractor_plow: %w[TPIA TPOP TPS],
    # 219-10 Water Tenders — light blue
    water_tender: %w[GWT1 GWT2 GWT3 GWT4 GWTA WTC1 WTC2 WTCA WTS1 WTS2 WTS3 WTSA WTT1 WTT2 WTTA FUT1 FUT2 FUT3 FUTA],
    # 219-11 Medical — pink
    medical: %w[EMPF AEMF AEMT AMB1 AMB2 AMB3 AMB4 AMBA EMTB EMTF EMTP IMDT IMSA IMSM IMST MEDL MEDV MERT MESU MESV REM1 REM2 REM3],
    # 219-12 Facilities — lavender
    facilities: %w[TNT1 TNT2 TNT3 TNT4 TNTA GENR OFFT SLP1 SLP2 SLP3 SLPA MFSU MSFU]
  }.freeze

  # Reverse lookup: position code → bucket symbol. Built once at load.
  POSITION_TO_BUCKET = POSITION_COLOR_BUCKETS.each_with_object({}) do |(bucket, codes), h|
    codes.each { |code| h[code] = bucket }
  end.freeze

  # Pulled from the same muted M800/900 palette used by the agency
  # colors above — same visual weight as a USFS/BLM/NPS strip so the
  # board stays quiet. Buckets follow the ICS 219 scheme.
  COLOR_SCHEMES = {
    crew:            { bg: '#2e7d32', fg: '#fff' }, # green       (219-2)   — same as USFS
    helicopter:      { bg: '#ad1457', fg: '#fff' }, # rose        (219-3)
    aircraft:        { bg: '#1565c0', fg: '#fff' }, # blue        (219-7)   — same as STATE
    engine:          { bg: '#b08800', fg: '#fff' }, # dark gold   (219-4)   — same as BLM
    dozer:           { bg: '#546e7a', fg: '#fff' }, # slate       (219-5)   — same as CONTRACT
    tractor_plow:    { bg: '#5d4037', fg: '#fff' }, # brown       (219-6)   — same as NPS
    water_tender:    { bg: '#00838f', fg: '#fff' }, # teal        (219-10)  — same as USFWS
    medical:         { bg: '#880e4f', fg: '#fff' }, # deep pink   (219-11)
    facilities:      { bg: '#6a1b9a', fg: '#fff' }, # purple      (219-12)  — same as COUNTY
    supply:          { bg: '#eceff1', fg: '#222' }, # near-white  (219-1, no S category yet)
    equipment_other: { bg: '#ef6c00', fg: '#fff' }, # dark orange (219-8 default)
    overhead_other:  { bg: '#4527a0', fg: '#fff' }, # indigo      (O default)
    unknown:         { bg: '#37474f', fg: '#fff' }
  }.freeze

  def resource_strip_color(resource)
    COLOR_SCHEMES[resource_color_bucket(resource)]
  end

  # Pick the bucket. Explicit position-code mappings win; otherwise fall
  # back to category (AIRCRAFT → aircraft/blue, EQUIPMENT → orange,
  # OVERHEAD → light purple). Crews with no explicit code still get
  # green by default.
  def resource_color_bucket(resource)
    code = resource.position.to_s.strip.upcase
    bucket = POSITION_TO_BUCKET[code]
    return bucket if bucket

    case resource.category
    when 'AIRCRAFT'  then :aircraft
    when 'EQUIPMENT' then :equipment_other
    when 'OVERHEAD'  then :overhead_other
    when 'CREW'      then :crew
    else :unknown
    end
  end

  # Returns a CSS class describing how close `today` is to the resource's
  # last work day. Applied as a filled "field" behind the LWD date on the
  # T-card so it stands out at a glance:
  #   past LWD (still assigned) → black field
  #   day of LWD                → red field, white text
  #   within 2 days of LWD      → orange field
  #   otherwise                 → plain black text (lwd-normal)
  # Returns nil only when the resource has no LWD to display.
  def lwd_status_class(resource)
    lwd = resource.last_work_day
    return nil if lwd.blank? || !lwd.respond_to?(:to_date)

    days_until = (lwd.to_date - Date.current).to_i
    case
    when days_until <  0 then 'lwd-past'
    when days_until == 0 then 'lwd-today'
    when days_until <= 2 then 'lwd-soon'
    else 'lwd-normal'
    end
  end

  private

  # Fallback equipment lookup — position codes DOZ*/AMB* are handled by
  # POSITION_ICON_OVERRIDES above; this is just the "generic equipment"
  # bucket that stays FontAwesome.
  def equipment_icon(code)
    return { type: :fa, name: 'fa-tint'  } if code.include?('TENDER') || code.include?('WATER')
    return { type: :fa, name: 'fa-truck' } if code.include?('ENGINE')
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
