require 'vcr'
require 'tmpdir'

VCR.configure do |c|
  c.cassette_library_dir = File.expand_path('../../vcr', __FILE__)
  c.hook_into :webmock
end

RSpec.configure do |c|
  c.include Fedex::Helpers

  shipper = { name: 'Sender', company: 'Company',
              phone_number: '555-555-5555',
              address: 'Main Street', city: 'Harrison', state: 'AR',
              postal_code: '72601', country_code: 'US' }
  recipient = { name: 'Recipient', company: 'Company',
                phone_number: '555-555-5555',
                address: 'Main Street', city: 'Frankin Park', state: 'IL',
                postal_code: '60131', country_code: 'US',
                residential: true }
  packages = [
    {
      weight: { units: 'LB', value: 2},
      dimensions: { length: 10, width: 5, height: 4, units: 'IN' }
    }
  ]
  filename = File.join(Dir.tmpdir, "label#{rand(15_000)}.pdf")

  c.around(:each, :vcr) do |example|
    name = underscorize(example.metadata[:full_description].split(/\s+/, 2).join('/')).gsub(/[^\w\/]+/, '_')
    VCR.use_cassette(name) { example.call }
  end

  c.around(:each, :vcr_with_shipment) do |example|
    name = underscorize(example.metadata[:full_description].split(/\s+/, 2).join('/')).gsub(/[^\w\/]+/, '_')
    VCR.use_cassette(name + '_shipment') do
      options = { shipper: shipper, recipient: recipient, packages: packages,
                  service_type: 'FEDEX_GROUND', filename: filename }
      shipment = Fedex::Shipment.new(fedex_credentials).ship(options)
      tn = shipment[:completed_shipment_detail][:completed_package_details][:tracking_ids][:tracking_number]
      @tn = tn
    end

    name = underscorize(example.metadata[:full_description].split(/\s+/, 2).join('/')).gsub(/[^\w\/]+/, '_')
    VCR.use_cassette(name) { example.call }
  end
end
