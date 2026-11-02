module DirectoryHelper
  STATUS_LABELS = {
    available: 'Available',
    on_assignment: 'On assignment',
    unavailable: 'Unavailable'
  }.freeze

  def directory_avatar(user, size: :sm)
    content_tag(:span, user.initials, class: "dir-avatar dir-avatar--#{size}", 'aria-hidden': true)
  end

  def directory_status_badge(status)
    content_tag(:span, STATUS_LABELS.fetch(status), class: "dir-status dir-status--#{status}")
  end

  # Self-reported quals get a dashed outline so they read differently
  # from certified ones at a glance.
  def qualification_badge(qual)
    classes = ['dir-qual']
    classes << 'dir-qual--self' if qual.self_reported?
    classes << 'dir-qual--trainee' if qual.trainee?
    title = "#{qual.position.title} · #{qual.status_label} · #{qual.certified? ? 'Certified' : 'Self-reported'}"
    content_tag(:span, qual.position.code + (qual.trainee? ? ' (T)' : ''), class: classes.join(' '), title: title)
  end

  # "Home unit ORCAD · Dispatch COIDC", skipping whichever is blank.
  def unit_and_dispatch(user, labels: false)
    parts = []
    parts << (labels ? "Home unit #{user.home_unit}" : user.home_unit) if user.home_unit.present?
    parts << (labels ? "Dispatch #{user.dispatch_center}" : user.dispatch_center) if user.dispatch_center.present?
    parts.join(' · ')
  end

  # "Mountain Time" for America/Denver; falls back to the stored name.
  def friendly_time_zone(tz)
    return if tz.blank?
    name = ActiveSupport::TimeZone::MAPPING.key(tz) || ActiveSupport::TimeZone[tz]&.name || tz
    name.sub(' (US & Canada)', '')
  end
end
