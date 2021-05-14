require 'rails_helper'
require 'support/gravity_helper'

describe OfferTotals do
  let(:gravity_artwork) { gravity_v1_artwork(_id: 'a-1', price_listed: 1000.00, edition_sets: [], domestic_shipping_fee_cents: 200_00, international_shipping_fee_cents: 300_00) }
  let(:shipping_info) { { shipping_name: 'Mike', shipping_address_line1: '401 Broadway', shipping_country: 'US', shipping_city: 'New York', buyer_phone_number: '777' } }
  let(:order) { Fabricate(:order, seller_id: 'partner-1', seller_type: 'gallery', buyer_id: 'buyer1', buyer_type: Order::USER, fulfillment_type: Order::SHIP, **shipping_info) }
  let(:offer) { Fabricate(:offer, order: order, from_id: 'partner-1', from_type: 'gallery', amount_cents: 800_00, shipping_total_cents: 0, tax_total_cents: 300_00) }
  let(:line_item) { Fabricate(:line_item, order: order, artwork_id: 'a-1') }
  let(:offer_totals) { OfferTotals.new(order, 100) }

  before do
    line_item.order
    allow(Adapters::GravityV1).to receive(:get).with('/artwork/a-1').and_return(gravity_artwork)
  end

  describe '#shipping_total_cents' do
    it 'initializes a shipping calculator to calculate shipping fee' do
      calculator = double(calculate: 5)
      expect(ShippingCalculator).to receive(:new).with(gravity_artwork, order).and_return calculator
      expect(offer_totals.shipping_total_cents).to be 5
    end
  end

  describe '#tax_total_cents' do
    context 'with artwork location and shipping data provided' do
      it 'initializes a tax calculator to calculate tax' do
        expect(order).to receive_messages(partner: { artsy_collects_sales_tax: true }, nexus_addresses: [])
        calculator = double(sales_tax: 7, 'artsy_should_remit_taxes?' => true)
        expect(Tax::CalculatorService).to receive(:new).and_return calculator
        expect(offer_totals.tax_total_cents).to eq 7
      end
    end

    context 'without artwork location' do
      it 'returns nil' do
        gravity_artwork[:location] = nil
        expect(offer_totals.tax_total_cents).to be nil
      end
    end

    context 'without shipping info' do
      let(:shipping_info) { {} }

      it 'returns nil' do
        expect(offer_totals.tax_total_cents).to be nil
      end
    end

    context 'without shipping pricing' do
      it 'returns nil' do
        allow(offer_totals).to receive(:shipping_total_cents).and_return nil
        expect(offer_totals.tax_total_cents).to be nil
      end
    end
  end
end
