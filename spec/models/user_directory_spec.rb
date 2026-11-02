require 'rails_helper'

RSpec.describe 'User directory rules' do
  let(:user) { create(:user) }

  describe 'assignment linking and status' do
    it 'links an overhead resource to the user with the same email' do
      resource = create(:resource, category: 'OVERHEAD', email: user.email.upcase)
      expect(resource.user).to eq(user)
    end

    it "doesn't link crews or equipment" do
      resource = create(:resource, category: 'CREW', email: user.email)
      expect(resource.user).to be_nil
    end

    it 'is On assignment while checked in and before the last work day' do
      incident = create(:incident, name: 'Cedar Ridge Fire')
      create(:resource, incident: incident, category: 'OVERHEAD', email: user.email,
                        fwd: Date.current - 2, assignment_length: 14)
      expect(user.directory_status).to eq(:on_assignment)
      expect(user.current_assignment.incident.name).to eq('Cedar Ridge Fire')
      expect(user.available_after).to eq(Date.current + 12)
    end

    it 'goes back to the self-set status once released' do
      user.update!(availability: :unavailable)
      create(:resource, category: 'OVERHEAD', email: user.email, fwd: Date.current - 2,
                        assignment_length: 14, release_date: Date.current)
      expect(user.reload.directory_status).to eq(:unavailable)
    end

    it 'ignores an old assignment that was never demobed' do
      create(:resource, category: 'OVERHEAD', email: user.email, fwd: Date.current - 60, assignment_length: 14)
      expect(user.directory_status).to eq(:available)
    end

    it "prefers the user's own available-after date" do
      create(:resource, category: 'OVERHEAD', email: user.email, fwd: Date.current, assignment_length: 14)
      user.update!(available_on: Date.current + 30)
      expect(user.available_after).to eq(Date.current + 30)
    end
  end

  describe QualificationPolicy do
    let(:admin) { create(:admin_user) }
    let(:position) { create(:position) }

    def allowed?(actor, qual, action)
      described_class.new(actor, qual).public_send(action)
    end

    it 'lets users manage only their own self-reported quals' do
      own = create(:qualification, user: user, position: position)
      theirs = create(:qualification, position: position)
      %i[update? destroy?].each do |action|
        expect(allowed?(user, own, action)).to be(true)
        expect(allowed?(user, theirs, action)).to be(false)
      end
    end

    it "doesn't let users change certified quals or certify their own" do
      certified = create(:qualification, :certified, user: user, position: position)
      expect(allowed?(user, certified, :update?)).to be(false)
      expect(allowed?(user, certified, :destroy?)).to be(false)

      self_rep = create(:qualification, user: user, position: create(:position))
      self_rep.source = :certified
      expect(allowed?(user, self_rep, :update?)).to be(false)
      expect(allowed?(user, Qualification.new(user: user, source: :certified), :create?)).to be(false)
    end

    it 'lets admins manage any qualification' do
      certified = create(:qualification, :certified, user: user, position: position)
      expect(allowed?(admin, certified, :update?)).to be(true)
      expect(allowed?(admin, certified, :destroy?)).to be(true)
    end
  end
end
