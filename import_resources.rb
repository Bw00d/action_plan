# =============================================================================
#  Import assigned resources into an Incident  (source: Resource_Assigned.xlsx)
#  Usage:  rails console  ->  load 'import_resources.rb'   (or paste contents)
# =============================================================================
#
#  Notes / assumptions (CHANGE THESE if they don't match your data):
#    * assignment_length is NOT in the spreadsheet but is required by the model.
#      Defaulting to 14 days (standard fire assignment). Edit per-resource later.
#    * Crew/engine members from the spreadsheet (rows like C-1.1, E-23.1) cannot
#      be stored as separate Resources (order_number is an integer, no parent
#      link), so they are rolled up into the parent's number_personnel count.
#    * Crews with no roster rows (C-5, C-6) and equipment with no operator rows
#      fall back to the DEFAULT_* values below.
#    * Re-running is safe: rows are matched on (incident, category, order_number),
#      so existing resources are updated rather than duplicated.
# =============================================================================

# ---- CONFIG -----------------------------------------------------------------
INCIDENT_ID                 = 10   # <<< REQUIRED: set to the target Incident id
DEFAULT_ASSIGNMENT_LENGTH   = 14    # days (not present in source data)
DEFAULT_CREW_SIZE           = 20    # for crews with no listed roster
DEFAULT_EQUIPMENT_PERSONNEL = 0     # for equipment with no listed operators
DRY_RUN                     = false  # true = preview only; set false to write
# -----------------------------------------------------------------------------

incident = (Incident.find_by(id: INCIDENT_ID) if INCIDENT_ID)
raise "Set INCIDENT_ID to a valid Incident id (got #{INCIDENT_ID.inspect})" unless incident

RESOURCES = [
  { order_number: 1, category: "OVERHEAD", name: "TULENSA, NENA ANDREW", position: "AFUL", agency: "BLM", checkin_date: "2026-06-21", personnel: 1 },
  { order_number: 2, category: "OVERHEAD", name: "SMIGLESKI, DANE Q", position: "LSCC", agency: "AK", checkin_date: "2026-06-20", personnel: 1 },
  { order_number: 3, category: "OVERHEAD", name: "SANFORD JR, EDWARD", position: "ICT3", agency: "AK", checkin_date: "2026-06-23", personnel: 1 },
  { order_number: 4, category: "OVERHEAD", name: "PARSLEY, LOGAN HALE", position: "OPS3", agency: "AK", checkin_date: "2026-06-20", personnel: 1 },
  { order_number: 5, category: "OVERHEAD", name: "SNYDER, MATTHEW D", position: "PSC3", agency: "AK", checkin_date: "2026-06-23", personnel: 1 },
  { order_number: 7, category: "OVERHEAD", name: "MORRIS-TITUS, MARIAH RAE", position: "FSCC", agency: "USFS", checkin_date: "2026-06-21", personnel: 1 },
  { order_number: 8, category: "OVERHEAD", name: "PHELAN, GEOFFREY", position: "TFLD", agency: "USFS", checkin_date: "2026-06-24", personnel: 1 },
  { order_number: 12, category: "OVERHEAD", name: "KUDO, KAY K", position: "ASGS", agency: "BLM", checkin_date: "2026-06-25", personnel: 1 },
  { order_number: 13, category: "OVERHEAD", name: "MARK, TRISTEN", position: "HECM", agency: "AK", checkin_date: "2026-06-23", personnel: 1 },
  { order_number: 14, category: "OVERHEAD", name: "WILSON, KAMERON", position: "HECM", agency: "AK", checkin_date: "2026-06-23", personnel: 1 },
  { order_number: 17, category: "OVERHEAD", name: "WARFORD, WEDGE ARNE", position: "AEMF", agency: "AK", checkin_date: "2026-06-22", personnel: 1 },
  { order_number: 18, category: "OVERHEAD", name: "VALENTINE, RICHARD JAMES", position: "EMPF", agency: "AK", checkin_date: "2026-06-22", personnel: 1 },
  { order_number: 19, category: "OVERHEAD", name: "SOLOMON, TERRY KATHRYN", position: "PIOC", agency: "AK", checkin_date: "2026-06-21", personnel: 1 },
  { order_number: 20, category: "OVERHEAD", name: "MARK SR, LARRY R", position: "SOF3", agency: "AK", checkin_date: "2026-06-23", personnel: 1 },
  { order_number: 21, category: "OVERHEAD", name: "EMRICK, ROBERT JON", position: "LSC3", agency: "CO", checkin_date: "2026-06-20", personnel: 1 },
  { order_number: 22, category: "OVERHEAD", name: "GLASS, DAN LOUIS", position: "HECM", agency: "AK", checkin_date: "2026-06-20", personnel: 1 },
  { order_number: 23, category: "OVERHEAD", name: "WADMAN, EMILIE", position: "EMPF", agency: "AK", checkin_date: "2026-06-23", personnel: 1 },
  { order_number: 24, category: "OVERHEAD", name: "REID, BRENTWOOD", position: "PSC3", agency: "OR", checkin_date: "2026-06-23", personnel: 1 },
  { order_number: 25, category: "OVERHEAD", name: "SPENCER, HEATHER LYNNETTE", position: "FSC3", agency: "AK", checkin_date: "2026-06-21", personnel: 1 },
  { order_number: 26, category: "OVERHEAD", name: "SIPHO, BRANDON R", position: "DZIA", agency: "AK", checkin_date: "2026-06-20", personnel: 1 },
  { order_number: 27, category: "OVERHEAD", name: "PENTJUSA, KRISTA", position: "DRIV", agency: "AK", checkin_date: "2026-06-20", personnel: 1 },
  { order_number: 28, category: "OVERHEAD", name: "SHORT, TORREY ADAMSON", position: "ICT3", agency: "AK", checkin_date: "2026-06-24", personnel: 1 },
  { order_number: 29, category: "OVERHEAD", name: "BOWMAN, LEWIS R", position: "FDUL", agency: "BLM", checkin_date: "2026-06-24", personnel: 1 },
  { order_number: 30, category: "OVERHEAD", name: "ALLEN, SAMUEL R", position: "PIO3", agency: "AK", checkin_date: "2026-06-22", personnel: 1 },
  { order_number: 31, category: "OVERHEAD", name: "STILLIE, BRITTANY", position: "ICT3", agency: "AK", checkin_date: "2026-06-20", personnel: 1 },
  { order_number: 32, category: "OVERHEAD", name: "FEARS, KYLE TAYLOR", position: "TFLD", agency: "USFS", checkin_date: "2026-06-25", personnel: 1 },
  { order_number: 33, category: "OVERHEAD", name: "LEAMING, GARY", position: "THSP", agency: "AK", checkin_date: "2026-06-24", personnel: 1 },
  { order_number: 34, category: "OVERHEAD", name: "FOSTER, BRET ALAN", position: "READ", agency: "AK", checkin_date: "2026-06-24", personnel: 1 },
  { order_number: 35, category: "OVERHEAD", name: "TIERNEY, SHANIKA K", position: "PTRC", agency: "AK", checkin_date: "2026-06-22", personnel: 1 },
  { order_number: 36, category: "OVERHEAD", name: "BURNETT, SARAH", position: "INBA", agency: "AK", checkin_date: nil, personnel: 1 },
  { order_number: 37, category: "OVERHEAD", name: "TONKIN, JACLYN K", position: "FSCC", agency: "AK", checkin_date: nil, personnel: 1 },
  { order_number: 38, category: "OVERHEAD", name: "ROOD, TRICIA", position: "EQTR", agency: "AK", checkin_date: nil, personnel: 1 },
  { order_number: 39, category: "OVERHEAD", name: "HOWARD, DYLAN T", position: "TFLD", agency: "AK", checkin_date: "2026-06-24", personnel: 1 },
  { order_number: 40, category: "OVERHEAD", name: "GUESS, KELLY", position: "PIOT", agency: "AK", checkin_date: "2026-06-24", personnel: 1 },
  { order_number: 41, category: "OVERHEAD", name: "MARSHALL, ANNE DANCZYK", position: "FFT1", agency: "BLM", checkin_date: "2026-06-25", personnel: 1 },
  { order_number: 42, category: "OVERHEAD", name: "MITCHELL, MONICA", position: "FFT2", agency: "AK", checkin_date: "2026-06-25", personnel: 1 },
  { order_number: 43, category: "OVERHEAD", name: "RUBIO, ATHENA", position: "FFT2", agency: "AK", checkin_date: "2026-06-25", personnel: 1 },
  { order_number: 44, category: "OVERHEAD", name: "VANN, LYDIA", position: "FFT2", agency: "AK", checkin_date: "2026-06-25", personnel: 1 },
  { order_number: 45, category: "OVERHEAD", name: "MERRITT, WILLOW", position: "HMGB", agency: "USFS", checkin_date: "2026-06-24", personnel: 1 },
  { order_number: 46, category: "OVERHEAD", name: "FRAZIER, THOMAS J", position: "OPS3", agency: "AK", checkin_date: nil, personnel: 1 },
  { order_number: 47, category: "OVERHEAD", name: "MAYER, MATTHEW JOHN", position: "PSC3", agency: "AK", checkin_date: nil, personnel: 1 },
  { order_number: 48, category: "OVERHEAD", name: "VALENTINE, RICHARD JAMES", position: "MEDL", agency: "AK", checkin_date: nil, personnel: 1 },
  { order_number: 1, category: "CREW", name: "CRW1 - PIONEER PEAK IHC", position: "CRW1", agency: "AK", checkin_date: "2026-06-20", personnel: 23 },
  { order_number: 4, category: "CREW", name: "CR2I - MIDNIGHT SUN IHC", position: "CR2I", agency: "BLM", checkin_date: "2026-06-21", personnel: 19 },
  { order_number: 5, category: "CREW", name: "CRW2 - AKCC RMF MOOSEHEART", position: "CRW2", agency: "PVT", checkin_date: "2026-06-24", personnel: nil },
  { order_number: 6, category: "CREW", name: "CRW2 - AKCC - RMF - CLEAR WATER", position: "CRW2", agency: "PVT", checkin_date: "2026-06-24", personnel: nil },
  { order_number: 7, category: "CREW", name: "CRW2 - YUKON CREW", position: "CRW2", agency: "AK", checkin_date: "2026-06-23", personnel: 20 },
  { order_number: 8, category: "CREW", name: "CRW2 - FAIRBANKS 1", position: "CRW2", agency: "AK", checkin_date: "2026-06-20", personnel: 24 },
  { order_number: 1, category: "EQUIPMENT", name: "ENG6 - AKFAS E264", position: "ENG6", agency: "AK", checkin_date: "2026-06-24", personnel: 2 },
  { order_number: 2, category: "EQUIPMENT", name: "EDSTROM - VIN: 2NP3LN0X6CM141587 - #18718", position: "WTS2", agency: "AK", checkin_date: "2026-06-24", personnel: nil },
  { order_number: 3, category: "EQUIPMENT", name: "FAIRBANKS PUMPING AND THAWING - VIN -734378 - 18723", position: "WTS2", agency: "AK", checkin_date: nil, personnel: nil },
  { order_number: 4, category: "EQUIPMENT", name: "TIMBERLINE EXCAVATION - VIN:4622", position: "DZR1", agency: "AK", checkin_date: "2026-06-20", personnel: nil },
  { order_number: 5, category: "EQUIPMENT", name: "TIMBERLINE EXCAVATION - VIN:14826", position: "DZR1", agency: "AK", checkin_date: "2026-06-20", personnel: nil },
  { order_number: 6, category: "EQUIPMENT", name: "FUT3 - AKAKD JET A 70192", position: "FUT3", agency: "BLM", checkin_date: "2026-06-23", personnel: nil },
  { order_number: 7, category: "EQUIPMENT", name: "OHV3 - UTV 102 - 18901 - 2022 RANGER - PIONEER PEAK", position: "OHV3", agency: "AK", checkin_date: nil, personnel: nil },
  { order_number: 8, category: "EQUIPMENT", name: "PIONEER PEAK - FORD F-550 - C-10", position: "PUP1", agency: "AK", checkin_date: nil, personnel: nil },
  { order_number: 9, category: "EQUIPMENT", name: "OHV3 - UTV 101 - 06895 - 2011 RHINO - PIONEER PEAK", position: "OHV3", agency: "AK", checkin_date: nil, personnel: nil },
  { order_number: 10, category: "EQUIPMENT", name: "PIONEER PEAK - 37374 - F-550 - C-10-2", position: "PUP1", agency: "AK", checkin_date: nil, personnel: nil },
  { order_number: 11, category: "EQUIPMENT", name: "TRLR - H&H TRAILER - A-7161 TG - 69281 - PIONEER PEAK", position: "TRLR", agency: "AK", checkin_date: nil, personnel: nil },
  { order_number: 12, category: "EQUIPMENT", name: "PIONEER PEAK - 42419 - GMC 3500 - C-10-1", position: "PUP1", agency: "AK", checkin_date: nil, personnel: nil },
  { order_number: 13, category: "EQUIPMENT", name: "PIONEER PEAK - 36543 - FORD F-350 UTILITY - C-10", position: "PUP1", agency: "AK", checkin_date: nil, personnel: nil },
  { order_number: 14, category: "EQUIPMENT", name: "TRLR - BEAR BACK - AK-5728 TG - 01809 - PIONEER PEAK", position: "TRLR", agency: "AK", checkin_date: nil, personnel: nil },
  { order_number: 15, category: "EQUIPMENT", name: "EDSTROM - UTV - VIN:100820", position: "OHV2", agency: "AK", checkin_date: nil, personnel: nil },
  { order_number: 16, category: "EQUIPMENT", name: "EDSTROM - UTV - VIN:102423", position: "OHV2", agency: "AK", checkin_date: "2026-06-20", personnel: nil },
  { order_number: 17, category: "EQUIPMENT", name: "GENES INC - UTV - 004955", position: "OHV2", agency: "AK", checkin_date: "2026-06-20", personnel: nil },
  { order_number: 18, category: "EQUIPMENT", name: "GENES INC - UTV - 004925", position: "OHV2", agency: "AK", checkin_date: nil, personnel: nil },
  { order_number: 19, category: "EQUIPMENT", name: "STATE FIRE WAREHOUSE - 34879", position: "FUT2", agency: "AK", checkin_date: nil, personnel: nil },
  { order_number: 20, category: "EQUIPMENT", name: "DELTA LEASING - KKT908 - DODGE 2500HD - 515227", position: "PUP2", agency: "PVT", checkin_date: "2026-06-20", personnel: nil },
  { order_number: 21, category: "EQUIPMENT", name: "WORKHORSE - VIN:25085 - WHEELED", position: "SKID", agency: "AK", checkin_date: nil, personnel: nil },
  { order_number: 22, category: "EQUIPMENT", name: "WORKHORSE SERVICES - 169321", position: "TRLR", agency: "AK", checkin_date: nil, personnel: nil },
  { order_number: 23, category: "EQUIPMENT", name: "ENG6 - AKFAS E269", position: "ENG6", agency: "AK", checkin_date: "2026-06-20", personnel: 2 },
  { order_number: 24, category: "EQUIPMENT", name: "ENG6 - AKMSS - E865 - 40038", position: "ENG6", agency: "AK", checkin_date: "2026-06-22", personnel: 3 },
  { order_number: 28, category: "EQUIPMENT", name: "ENG6 - AKTNF 633", position: "ENG6", agency: "USFS", checkin_date: "2026-06-23", personnel: 3 },
  { order_number: 29, category: "EQUIPMENT", name: "NENANA VFD - TACTICAL WATER TENDER - XYE385 - 98386", position: "WTT1", agency: "AK", checkin_date: "2026-06-24", personnel: nil },
  { order_number: 30, category: "EQUIPMENT", name: "ALASKA AUTO LEASING - T30555 - CHEVY 2500 - 238531", position: "PUP2", agency: "PVT", checkin_date: "2026-06-21", personnel: nil },
  { order_number: 31, category: "EQUIPMENT", name: "ALASKA AUTO LEASING - T300493 - CHEVY GRAY- 238641", position: "PUP2", agency: "PVT", checkin_date: "2026-06-21", personnel: nil },
  { order_number: 32, category: "EQUIPMENT", name: "TRI-VALLEY VFD - 86538 - YZF834", position: "WTT1", agency: "AK", checkin_date: "2026-06-24", personnel: nil },
  { order_number: 33, category: "EQUIPMENT", name: "CAMERON EQUIPMENT - ATV - 15959", position: "VATV", agency: "AK", checkin_date: nil, personnel: nil },
  { order_number: 34, category: "EQUIPMENT", name: "CAMERON EQUIPMENT - ATV - 51632", position: "VATV", agency: "AK", checkin_date: nil, personnel: nil },
  { order_number: 35, category: "EQUIPMENT", name: "CAMERON EQUIPMENT - ATV - 45791", position: "VATV", agency: "AK", checkin_date: nil, personnel: nil },
  { order_number: 37, category: "EQUIPMENT", name: "LANCE MEYER - CAN-AM DEFENDER - FIELD HIRE", position: "VATV", agency: "AK", checkin_date: nil, personnel: nil },
  { order_number: 38, category: "EQUIPMENT", name: "WORKHORSE - 2036135", position: "TRLR", agency: "AK", checkin_date: nil, personnel: nil },
  { order_number: 39, category: "EQUIPMENT", name: "WILL NELSON - 2022 POLARIS - FIELD HIRE", position: "VATV", agency: "AK", checkin_date: nil, personnel: nil },
  { order_number: 40, category: "EQUIPMENT", name: "ENG6 - ANDERSON VFD - VIN:669575", position: "WAT4", agency: "AK", checkin_date: "2026-06-23", personnel: 2 },
  { order_number: 41, category: "EQUIPMENT", name: "CHARLIE RATHBONE - ATV - POLARIS 6X6", position: "VATV", agency: "AK", checkin_date: nil, personnel: nil },
  { order_number: 42, category: "EQUIPMENT", name: "JOSH CHRISTENSEN - 2014 FORMAN 4X4 ATV", position: "VATV", agency: "AK", checkin_date: nil, personnel: nil },
  { order_number: 43, category: "EQUIPMENT", name: "KATIE GRIEBE - 2006 POLARIS SPORTSMAN 4X4 ATV", position: "VATV", agency: "AK", checkin_date: nil, personnel: nil },
  { order_number: 45, category: "EQUIPMENT", name: "CHUGACHMUIT - YZF343 - 31666", position: "PUP2", agency: "AK", checkin_date: nil, personnel: nil },
  { order_number: 46, category: "EQUIPMENT", name: "CHUGACHMIUT - YZK720 - 50547", position: "PUP1", agency: "AK", checkin_date: nil, personnel: nil },
  { order_number: 47, category: "EQUIPMENT", name: "CHUGACHMIUT - YZK719 - 50546", position: "PUP1", agency: "AK", checkin_date: nil, personnel: nil },
  { order_number: 48, category: "EQUIPMENT", name: "CHUGACHMIUT - YZJ778 - 49890", position: "PUP1", agency: "AK", checkin_date: nil, personnel: nil },
  { order_number: 49, category: "EQUIPMENT", name: "CHUGACHMIUT - YZH983 - 77823", position: "PUP2", agency: "AK", checkin_date: nil, personnel: nil },
  { order_number: 50, category: "EQUIPMENT", name: "CHUGACHMIUT - YZH673 - 1FT7W2B6XLEC49309", position: "PUP2", agency: "AK", checkin_date: nil, personnel: nil },
  { order_number: 51, category: "EQUIPMENT", name: "ALASKA AUTO LEASING - KSS612 - SILVERADO 250 - 238272", position: "PUP2", agency: "PVT", checkin_date: "2026-06-22", personnel: nil },
  { order_number: 52, category: "EQUIPMENT", name: "TWIN SPRINGS WATER - KAZ716 - VIN:18018", position: "POT2", agency: "AK", checkin_date: "2026-06-23", personnel: nil },
  { order_number: 53, category: "EQUIPMENT", name: "NORTHERN RAIN - GNU686 - VIN:68579", position: "GWT3", agency: "AK", checkin_date: "2026-06-23", personnel: nil },
  { order_number: 54, category: "EQUIPMENT", name: "SANTA'S STITCHES - 7056CA - 00391", position: "HND2", agency: "AK", checkin_date: nil, personnel: nil },
  { order_number: 56, category: "EQUIPMENT", name: "ENG6 - AKFAS E267", position: "ENG6", agency: "AK", checkin_date: "2026-06-20", personnel: 2 },
  { order_number: 57, category: "EQUIPMENT", name: "ALASKA AUTO LEASING - KST384 - SILVERADO 2500 - 238034", position: "PUP2", agency: "PVT", checkin_date: "2026-06-22", personnel: nil },
  { order_number: 58, category: "EQUIPMENT", name: "ALASKA AUTO LEASING - KSS608 - CHEVY 2500 - 238636", position: "PUP2", agency: "PVT", checkin_date: "2026-06-23", personnel: nil },
  { order_number: 59, category: "EQUIPMENT", name: "DZR2 - AKFAS 35328", position: "DZR2", agency: "AK", checkin_date: "2026-06-20", personnel: nil },
  { order_number: 60, category: "EQUIPMENT", name: "ALASKA AUTO LEASING - T300554 - CHEVY 2500 - 238135", position: "PUP2", agency: "PVT", checkin_date: "2026-06-23", personnel: nil },
  { order_number: 61, category: "EQUIPMENT", name: "ENG6 - ANDERSON VFD - VIN:669575", position: "ENG6", agency: "AK", checkin_date: "2026-06-24", personnel: nil },
  { order_number: 62, category: "EQUIPMENT", name: "ARCHANGEL SERVICES - VIN:201003 - 6BB392", position: "OHV1", agency: "AK", checkin_date: nil, personnel: nil },
  { order_number: 63, category: "EQUIPMENT", name: "ENG7 - CV-873 - 42091", position: "ENG7", agency: "AK", checkin_date: nil, personnel: nil },
].freeze

created = updated = invalid = 0
problems = []

RESOURCES.each do |row|
  np = row[:personnel] || case row[:category]
                          when "CREW"      then DEFAULT_CREW_SIZE
                          when "EQUIPMENT" then DEFAULT_EQUIPMENT_PERSONNEL
                          else 1
                          end

  res = Resource.find_or_initialize_by(
    incident_id:  incident.id,
    category:     row[:category],
    order_number: row[:order_number]
  )
  was_new = res.new_record?

  res.assign_attributes(
    name:              row[:name],
    position:          row[:position],
    agency:            row[:agency],
    number_personnel:  np,
    assignment_length: DEFAULT_ASSIGNMENT_LENGTH,
    checkin_date:      (Date.parse(row[:checkin_date]) if row[:checkin_date]),
    fwd:               (Date.parse(row[:checkin_date]) if row[:checkin_date])
  )

  label = format("%-2s-%-3d %s", row[:category][0], row[:order_number], row[:name])

  if DRY_RUN
    if res.valid?
      puts "  #{was_new ? 'NEW' : 'UPD'}  #{label}  (personnel: #{np})"
    else
      invalid += 1
      problems << "#{label} -> #{res.errors.full_messages.join('; ')}"
      puts "  BAD  #{label}  -> #{res.errors.full_messages.join('; ')}"
    end
  elsif res.save
    was_new ? created += 1 : updated += 1
  else
    invalid += 1
    problems << "#{label} -> #{res.errors.full_messages.join('; ')}"
  end
end

puts "-" * 70
if DRY_RUN
  puts "DRY RUN: #{RESOURCES.size} rows previewed for incident ##{incident.id} (#{incident.try(:name)})."
  puts "#{invalid} row(s) would fail validation." if invalid.positive?
  puts "Looks good? Set DRY_RUN = false and re-run to write."
else
  puts "Done for incident ##{incident.id}. Created: #{created}  Updated: #{updated}  Invalid: #{invalid}"
  problems.each { |p| puts "  ! #{p}" }
end
