require 'rails_helper'

RSpec.describe 'Profile settings and qualification rules', type: :request do
  let(:position) { create(:position, code: 'DIVS') }
  let(:owner) { create(:user) }
  let(:someone_else) { create(:user) }

  before { login_as(owner, scope: :user) }

  describe 'profile' do
    it 'renders the edit page with your contacts and quals' do
      create(:contact_method, user: owner, value: '541-555-0123')
      create(:qualification, user: owner, position: position)
      get edit_profile_path
      expect(response).to have_http_status(200)
      expect(response.body).to include('(541) 555-0123', 'DIVS', 'Emergency contact')
    end

    it 'updates your own status, availability and units' do
      patch profile_path, params: { user: { availability: 'unavailable', available_on: '2026-12-01',
                                            home_unit: 'orcof', dispatch_center: ' orcoc ' } }
      owner.reload
      expect(owner).to be_marked_unavailable
      expect(owner.available_on).to eq(Date.new(2026, 12, 1))
      expect([owner.home_unit, owner.dispatch_center]).to eq(%w[ORCOF ORCOC])
    end

    it "ignores attempts to change role through the profile form" do
      patch profile_path, params: { user: { role: 'admin', home_unit: 'X' } }
      expect(owner.reload).not_to be_admin
    end
  end

  describe 'contact methods' do
    it 'start hidden unless shared is chosen' do
      post profile_contact_methods_path, params: { contact_method: { kind: 'phone', value: '541-555-0123' } }
      expect(owner.contact_methods.last.shared).to be(false)
    end

    it "can't be changed on someone else's profile" do
      theirs = create(:contact_method, user: someone_else, shared: false)
      # Scoped to current_user, so it's not found (a 404 in production).
      expect {
        patch profile_contact_method_path(theirs), params: { contact_method: { shared: true } }
      }.to raise_error(ActiveRecord::RecordNotFound)
      expect(theirs.reload.shared).to be(false)
    end
  end

  describe 'qualifications' do
    it 'are added to your own profile' do
      post profile_qualifications_path,
           params: { qualification: { position_id: position.id, status: 'trainee', user_id: someone_else.id } }
      expect(owner.qualifications.last.position).to eq(position)
      expect(owner.qualifications.last).to be_trainee
      expect(someone_else.qualifications).to be_empty
    end

    it "can't be added twice for the same position" do
      create(:qualification, user: owner, position: position)
      post profile_qualifications_path, params: { qualification: { position_id: position.id, status: 'qualified' } }
      expect(owner.qualifications.count).to eq(1)
    end

    it 'can be edited and removed by their owner' do
      qual = create(:qualification, user: owner, position: position)
      patch profile_qualification_path(qual), params: { qualification: { status: 'trainee' } }
      expect(qual.reload).to be_trainee
      expect { delete profile_qualification_path(qual) }.to change(Qualification, :count).by(-1)
    end

    it "can't touch another user's qualifications" do
      theirs = create(:qualification, user: someone_else, position: position)
      expect { delete profile_qualification_path(theirs) }.to raise_error(ActiveRecord::RecordNotFound)
      expect(Qualification.exists?(theirs.id)).to be(true)
    end
  end
end
