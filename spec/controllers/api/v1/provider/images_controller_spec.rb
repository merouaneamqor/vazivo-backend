# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Api::V1::Provider::ImagesController, type: :controller do
  let(:user) { create(:user, provider_status: 'confirmed') }
  let(:business) { create(:business, user: user) }
  let(:valid_image) { fixture_file_upload('spec/fixtures/files/test.jpg', 'image/jpeg') }

  before do
    sign_in user
  end

  describe 'POST #create' do
    context 'with valid images' do
      it 'uploads images successfully' do
        allow(Cloudinary::Uploader).to receive(:upload).and_return(
          'secure_url' => 'https://res.cloudinary.com/test/image.jpg',
          'public_id' => 'businesses/1/test_uuid',
          'width' => 1920,
          'height' => 1080
        )

        post :create, params: { business_id: business.id, images: [valid_image] }

        expect(response).to have_http_status(:created)
        json = JSON.parse(response.body)
        expect(json['images']).to be_an(Array)
        expect(json['images'].first['url']).to be_present
      end
    end

    context 'with invalid file type' do
      it 'rejects non-image files' do
        invalid_file = fixture_file_upload('spec/fixtures/files/test.pdf', 'application/pdf')
        
        post :create, params: { business_id: business.id, images: [invalid_file] }

        expect(response).to have_http_status(:unprocessable_entity)
      end
    end

    context 'with oversized file' do
      it 'rejects files larger than 5MB' do
        large_file = fixture_file_upload('spec/fixtures/files/test.jpg', 'image/jpeg')
        allow(large_file).to receive(:size).and_return(6.megabytes)

        post :create, params: { business_id: business.id, images: [large_file] }

        expect(response).to have_http_status(:unprocessable_entity)
      end
    end

    context 'when image limit reached' do
      it 'rejects upload' do
        allow_any_instance_of(Business).to receive_message_chain(:images, :count).and_return(10)

        post :create, params: { business_id: business.id, images: [valid_image] }

        expect(response).to have_http_status(:unprocessable_entity)
        json = JSON.parse(response.body)
        expect(json['error']).to include('Maximum')
      end
    end
  end

  describe 'DELETE #destroy' do
    let(:public_id) { 'businesses/1/test_uuid' }

    context 'with valid public_id' do
      it 'deletes image successfully' do
        allow(Cloudinary::Uploader).to receive(:destroy).and_return('result' => 'ok')

        delete :destroy, params: { business_id: business.id, id: public_id }

        expect(response).to have_http_status(:ok)
        json = JSON.parse(response.body)
        expect(json['message']).to eq('Image deleted successfully')
      end
    end

    context 'with invalid public_id' do
      it 'returns error' do
        allow(Cloudinary::Uploader).to receive(:destroy).and_return('result' => 'not found')

        delete :destroy, params: { business_id: business.id, id: public_id }

        expect(response).to have_http_status(:unprocessable_entity)
      end
    end
  end
end
