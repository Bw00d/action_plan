class CommoPlan < ApplicationRecord
  # 16 channels per page — matches the printable page capacity AND the
  # channel count on a standard programmable radio.
  CHANNELS_PER_PAGE = 16

  belongs_to :plan
  # Position is 1-based, dense within a plan. id is a stable tiebreaker
  # for the rare row created with the same position.
  has_many :commo_items, -> { order(:position, :id) }, dependent: :destroy

  # Fresh plan → seed one page of 16 empty channel rows. Users just fill
  # them in like a paper 205, no need to add channels one at a time.
  after_create :seed_first_page

  # Total pages currently allocated (16 items per page, rounded up).
  def page_count
    [(commo_items.count.to_f / CHANNELS_PER_PAGE).ceil, 1].max
  end

  # Append another 16 blank channels — one more physical page on the PDF.
  # Returns the newly-created items. No-op if the position column hasn't
  # been migrated yet (safer than crashing plan creation on a boot with
  # a stale schema cache or an un-migrated env).
  def add_page!
    return [] unless position_column_present?
    start_pos = (commo_items.maximum(:position) || 0) + 1
    Array.new(CHANNELS_PER_PAGE) do |i|
      commo_items.create!(position: start_pos + i)
    end
  end

  # Top the plan up to the next whole page — used by the show action so
  # legacy plans (created before after_create :seed_first_page) always
  # render a complete 16-row page. Idempotent; skips when full.
  def ensure_full_pages!
    return unless position_column_present?
    # Backfill positions on any legacy items that migrated without one
    # (belt-and-suspenders alongside the SQL backfill in the migration).
    commo_items.where(position: nil).order(:created_at, :id).each_with_index do |item, i|
      item.update_columns(position: i + 1)
    end
    current = commo_items.count
    missing = if current.zero?
                CHANNELS_PER_PAGE
              elsif (current % CHANNELS_PER_PAGE).positive?
                CHANNELS_PER_PAGE - (current % CHANNELS_PER_PAGE)
              else
                0
              end
    return if missing.zero?

    start_pos = (commo_items.maximum(:position) || 0) + 1
    missing.times do |i|
      commo_items.create!(position: start_pos + i)
    end
  end

  private

  def seed_first_page
    add_page!
  rescue => e
    Rails.logger.warn "CommoPlan##{id} seed_first_page failed: #{e.class}: #{e.message}"
    nil
  end

  def position_column_present?
    CommoItem.column_names.include?('position')
  end
end
