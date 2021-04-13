ENV['LAMBDA_WORKER']="lambda"

require 'rails_helper'
require 'webmock/rspec'
require 'byebug'

RSpec.describe Posting, type: :model do
  before { Time.zone ='Tokyo' }
  after { Time.zone ='UTC' }
  let(:posting) { Posting.new(attributes) }

  describe 'create' do
    let(:attributes) { { id: "1234567890abcd" } }
    describe 'access dynamodb actually' do
      subject { posting.create }
      before { WebMock.disable! }
      after { WebMock.enable! }
      it 'register data with id, post_time, expired_limit' do
        expect{ subject }.not_to raise_error
        puts "check dynamodb if test data is exist"
      end
    end
    describe 'values of posting' do
      subject { posting.create(options: options) }
      before { travel_to(Time.zone.local(2021, 1, 1, 10, 15, 55)) }
      after { travel_back }
      context 'default' do
        let(:options) { {} }
        it 'compute and includes id, post_time, expired_limit' do
          dynamodb_client_mock = double('Dynamodb Client')
          allow(posting).to receive(:dynamodb_client).and_return(dynamodb_client_mock)
          allow(dynamodb_client_mock).to receive(:put_item).and_return(true)

          subject
          expect( posting.id ).to eq "1234567890abcd"
          expect( posting.post_time ).to eq "20210101T101555"
          expect( posting.expired_limit ).to eq "20210129T000000"
        end
      end
      context 'overwrite expiration with positive value' do
        let(:options) { { expiration: 5 } }
        it 'overwrite and compute expired_limit in 5 days' do
          dynamodb_client_mock = double('Dynamodb Client')
          allow(posting).to receive(:dynamodb_client).and_return(dynamodb_client_mock)
          allow(dynamodb_client_mock).to receive(:put_item).and_return(true)

          subject
          expect( posting.expired_limit ).to eq "20210106T000000"
        end
      end
      context 'overwrite expiration with 0' do
        let(:options) { { expiration: 0 } }
        it 'overwrite and compute expired_limit to the midnight of post_date' do
          dynamodb_client_mock = double('Dynamodb Client')
          allow(posting).to receive(:dynamodb_client).and_return(dynamodb_client_mock)
          allow(dynamodb_client_mock).to receive(:put_item).and_return(true)

          subject
          expect( posting.expired_limit ).to eq "20210101T000000"
        end
      end
      context 'overwrite expiration with negative value' do
        let(:options) { { expiration: -1 } }
        it 'overwrite and compute expired_limit to the midnight of post_date' do
          dynamodb_client_mock = double('Dynamodb Client')
          allow(posting).to receive(:dynamodb_client).and_return(dynamodb_client_mock)
          allow(dynamodb_client_mock).to receive(:put_item).and_return(true)

          expect{ subject }.to raise_error(ArgumentError)
        end
      end
    end
    describe 'error handling' do
      subject { posting.create }
      it 'puts log and raises ModelStorageError when dynamoDB raised Aws::DynamoDB::Errors::ServiceError' do
        dynamodb_client_mock = double('Dynamodb Client')
        allow(posting).to receive(:dynamodb_client).and_return(dynamodb_client_mock)
        allow(dynamodb_client_mock).to receive(:put_item).and_raise(Aws::DynamoDB::Errors::ServiceError.new({}, "message"))

        expect( Rails.logger ).to receive(:error).with("AWS DynamoDB service error Aws::DynamoDB::Errors::ServiceError with message, message")
        expect{ subject }.to raise_error(ModelStorageError)
      end
      it 'puts log and raises ModelStorageError when dynamoDB raised Aws::Errors::ServiceError' do
        dynamodb_client_mock = double('Dynamodb Client')
        allow(posting).to receive(:dynamodb_client).and_return(dynamodb_client_mock)
        allow(dynamodb_client_mock).to receive(:put_item).and_raise(Aws::Errors::ServiceError.new({}, "message"))

        expect( Rails.logger ).to receive(:error).with("AWS DynamoDB service error Aws::Errors::ServiceError with message, message")
        expect{ subject }.to raise_error(ModelStorageError)
      end
      it 'puts log and raises ModelStorageError when dynamoDB raised Aws::Sigv4::Errors::MissingCredentialsError' do
        dynamodb_client_mock = double('Dynamodb Client')
        allow(posting).to receive(:dynamodb_client).and_return(dynamodb_client_mock)
        allow(dynamodb_client_mock).to receive(:put_item).and_raise(Aws::Sigv4::Errors::MissingCredentialsError)

        expect( Rails.logger ).to receive(:error).with("Aws::Sigv4::Errors::MissingCredentialsError")
        expect{ subject }.to raise_error(ModelStorageError)
      end
      it 'puts log and raises ModelStorageError when dynamoDB raised Aws::Sigv4::Errors::MissingRegionError' do
        dynamodb_client_mock = double('Dynamodb Client')
        allow(posting).to receive(:dynamodb_client).and_return(dynamodb_client_mock)
        allow(dynamodb_client_mock).to receive(:put_item).and_raise(Aws::Sigv4::Errors::MissingRegionError)

        expect( Rails.logger ).to receive(:error).with("Aws::Sigv4::Errors::MissingRegionError")
        expect{ subject }.to raise_error(ModelStorageError)
      end
      it 'raises ModelStorageError when dynamoDB raised RuntimeError' do
        dynamodb_client_mock = double('Dynamodb Client')
        allow(posting).to receive(:dynamodb_client).and_return(dynamodb_client_mock)
        allow(dynamodb_client_mock).to receive(:put_item).and_raise(RuntimeError)

        expect{ subject }.to raise_error(ModelStorageError)
      end
    end
  end
  describe 'expire' do
    let(:attributes) { {} }
    subject { posting.expire }
    describe 'access dynamodb actually' do
      before { WebMock.disable! }
      after { WebMock.enable! }
      before(:each) { Posting.new({ id: "1234567890abcd" }).create( options: { expiration: expiration }) }
      context 'with expired data' do
        let(:expiration) { 0 }
        it 'deletes expired data' do
          is_expected.to eq ["1234567890abcd"]
        end
      end
      context 'with nearly expired data' do
        let(:expiration) { 1 }
        it 'does not deletes data which has 1 day to be expired' do
          is_expected.to eq []
        end
      end
    end
    describe 'error handling' do
      it 'puts log and raises ModelStorageError when dynamoDB raised Aws::DynamoDB::Errors::ServiceError' do
        dynamodb_client_mock = double('Dynamodb Client')
        allow(posting).to receive(:dynamodb_client).and_return(dynamodb_client_mock)
        allow(dynamodb_client_mock).to receive(:scan).and_raise(Aws::DynamoDB::Errors::ServiceError.new({}, "message"))
        allow(dynamodb_client_mock).to receive(:delete_item).and_raise(Aws::DynamoDB::Errors::ServiceError.new({}, "message"))

        expect( Rails.logger ).to receive(:error).with("AWS DynamoDB service error Aws::DynamoDB::Errors::ServiceError with message, message")
        expect{ subject }.to raise_error(ModelStorageError)
      end
      it 'puts log and raises ModelStorageError when dynamoDB raised Aws::Errors::ServiceError' do
        dynamodb_client_mock = double('Dynamodb Client')
        allow(posting).to receive(:dynamodb_client).and_return(dynamodb_client_mock)
        allow(dynamodb_client_mock).to receive(:scan).and_raise(Aws::Errors::ServiceError.new({}, "message"))
        allow(dynamodb_client_mock).to receive(:delete_item).and_raise(Aws::Errors::ServiceError.new({}, "message"))

        expect( Rails.logger ).to receive(:error).with("AWS DynamoDB service error Aws::Errors::ServiceError with message, message")
        expect{ subject }.to raise_error(ModelStorageError)
      end
      it 'puts log and raises ModelStorageError when dynamoDB raised Aws::Sigv4::Errors::MissingCredentialsError' do
        dynamodb_client_mock = double('Dynamodb Client')
        allow(posting).to receive(:dynamodb_client).and_return(dynamodb_client_mock)
        allow(dynamodb_client_mock).to receive(:scan).and_raise(Aws::Sigv4::Errors::MissingCredentialsError)
        allow(dynamodb_client_mock).to receive(:delete_item).and_raise(Aws::Sigv4::Errors::MissingCredentialsError)

        expect( Rails.logger ).to receive(:error).with("Aws::Sigv4::Errors::MissingCredentialsError")
        expect{ subject }.to raise_error(ModelStorageError)
      end
      it 'puts log and raises ModelStorageError when dynamoDB raised Aws::Sigv4::Errors::MissingRegionError' do
        dynamodb_client_mock = double('Dynamodb Client')
        allow(posting).to receive(:dynamodb_client).and_return(dynamodb_client_mock)
        allow(dynamodb_client_mock).to receive(:scan).and_raise(Aws::Sigv4::Errors::MissingRegionError)
        allow(dynamodb_client_mock).to receive(:delete_item).and_raise(Aws::Sigv4::Errors::MissingRegionError)

        expect( Rails.logger ).to receive(:error).with("Aws::Sigv4::Errors::MissingRegionError")
        expect{ subject }.to raise_error(ModelStorageError)
      end
      it 'raises ModelStorageError when dynamoDB raised RuntimeError' do
        dynamodb_client_mock = double('Dynamodb Client')
        allow(posting).to receive(:dynamodb_client).and_return(dynamodb_client_mock)
        allow(dynamodb_client_mock).to receive(:scan).and_raise(RuntimeError)
        allow(dynamodb_client_mock).to receive(:delete_item).and_raise(RuntimeError)

        expect{ subject }.to raise_error(ModelStorageError)
      end
    end

  end
end
