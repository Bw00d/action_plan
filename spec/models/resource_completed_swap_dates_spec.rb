require 'rails_helper'

RSpec.describe Resource, '#completed_swap_dates', type: :model do
  let(:resource) do
    create(:resource, leader: 'Smith', fwd: Date.new(2026, 10, 1), assignment_length: 14)
  end

  def promoted_entry(leader, day)
    resource.resource_events.create!(kind: :work, leader: leader, fwd: day, actual_fwd: day)
  end

  it 'does not count the original operator as a swap' do
    expect(resource.completed_swap_dates).to eq([])
  end

  it 'returns the day each new leader took over' do
    promoted_entry('Jones', Date.new(2026, 10, 8))
    promoted_entry('Lee', Date.new(2026, 10, 12))

    expect(resource.reload.completed_swap_dates)
      .to eq([Date.new(2026, 10, 8), Date.new(2026, 10, 12)])
  end

  it 'skips a return from R&R by the same leader' do
    promoted_entry(resource.leader, Date.new(2026, 10, 8))

    expect(resource.reload.completed_swap_dates).to eq([])
  end

  it 'skips swaps that are scheduled but not executed' do
    resource.resource_events.create!(kind: :work, leader: 'Jones', fwd: Date.new(2026, 10, 8))

    expect(resource.reload.completed_swap_dates).to eq([])
  end

  it 'tags the swap day on the calendar' do
    promoted_entry('Jones', Date.new(2026, 10, 8))
    resource.resource_events.create!(kind: :work, leader: 'Lee', fwd: Date.new(2026, 10, 10))

    html = ApplicationController.render(partial: 'boards/card_calendar',
                                        locals:  { resource: resource.reload })

    expect(html.scan('<span class="cal-tag">SWPD</span>').size).to eq(1)
    expect(html.scan('<span class="cal-tag">SWAP</span>').size).to eq(1)
    expect(html).to include('Swap completed')
  end
end
