require 'rails_helper'

RSpec.describe PhoneNumber do
  it 'formats US numbers however they were typed' do
    ['5415550123', '541-555-0123', '541.555.0123', '(541)555-0123', '1 541 555 0123', '+1 (541) 555-0123'].each do |raw|
      expect(described_class.format(raw)).to eq('(541) 555-0123'), raw
    end
  end

  it 'keeps an extension' do
    expect(described_class.format('541-555-0123 x12')).to eq('(541) 555-0123 ext. 12')
    expect(described_class.format('5415550123 ext. 7')).to eq('(541) 555-0123 ext. 7')
  end

  it 'leaves anything else as typed' do
    ['+44 20 7946 0958', '555-0123', '8816 2345 6789'].each do |raw|
      expect(described_class.format(raw)).to eq(raw)
    end
    expect(described_class.format('')).to eq('')
  end

  it 'is applied when contacts and emergency phones are saved' do
    user = create(:user, emergency_contact_phone: '208.555.0172')
    phone = create(:contact_method, user: user, kind: :phone, value: '541 555 0123')
    email = create(:contact_method, user: user, kind: :email, value: 'pat@example.com')
    expect(user.emergency_contact_phone).to eq('(208) 555-0172')
    expect(phone.value).to eq('(541) 555-0123')
    expect(email.value).to eq('pat@example.com')
  end
end
