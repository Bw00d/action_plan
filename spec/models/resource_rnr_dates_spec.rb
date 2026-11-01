require 'rails_helper'

RSpec.describe Resource, 'R&R calendar dates', type: :model do
  include ActiveSupport::Testing::TimeHelpers

  # Mid-month, so no day appears in two month grids on the calendar.
  let(:today) { Date.new(2026, 10, 14) }
  let(:resource) do
    create(:resource, leader: 'Smith', fwd: today - 10, assignment_length: 21)
  end

  before { travel_to today }
  after  { travel_back }

  def rnr_entry(attrs)
    resource.resource_events.create!({ kind: :rnr }.merge(attrs))
  end

  it 'splits an R&R under way at today' do
    rnr_entry(fwd: today - 1, lwd: today + 1)

    expect(resource.reload.completed_rnr_dates).to eq([today - 1])
    expect(resource.scheduled_rnr_dates).to eq([today, today + 1])
  end

  it 'treats a future R&R as scheduled' do
    rnr_entry(fwd: today + 2, lwd: today + 3)

    expect(resource.reload.completed_rnr_dates).to eq([])
    expect(resource.scheduled_rnr_dates).to eq([today + 2, today + 3])
  end

  it 'counts only the days taken when an R&R ends early' do
    rnr_entry(fwd: today - 2, lwd: today + 3, actual_lwd: today)

    expect(resource.reload.completed_rnr_dates).to eq([today - 2, today - 1, today])
    expect(resource.scheduled_rnr_dates).to eq([])
  end

  it 'starts from the actual date when an R&R starts early' do
    rnr_entry(fwd: today + 1, lwd: today + 2, actual_fwd: today)

    expect(resource.reload.scheduled_rnr_dates).to eq([today, today + 1, today + 2])
  end

  it 'tags R&R days on the calendar' do
    rnr_entry(fwd: today - 2, lwd: today - 1)
    rnr_entry(fwd: today + 1, lwd: today + 2)

    html = ApplicationController.render(partial: 'boards/card_calendar',
                                        locals:  { resource: resource.reload })

    expect(html.scan('<span class="cal-tag">R&amp;R</span>').size).to eq(4)
    expect(html.scan(/cal-rnr-taken"/).size).to eq(2)
    expect(html).to include('Scheduled R&amp;R', 'R&amp;R completed')
  end
end
