ENV['LAMBDA_WORKER']="lambda"

require 'rails_helper'
require 'webmock/rspec'
require 'byebug'

module RSpec
  module Custom
    class AssertionError
    end
  end
end

# Load whole sources from which includes ArticlesController 
ArticlesController

API_ITEM_EXAMPLE = {
  url: 'https://www.example.com',
  title: 'RSpecのテストについて',
  body: '# ヘッダー\n本文',
  user: {id: 'test_user'},
  created_at: '2021-04-01T00:00:00+09:00',
  updated_at: '2021-04-01T00:00:00+09:00'
}

class MockFaradayResponse < Faraday::Response
  def initialize(status: 999, body: '')
    super
    @status = status
    @body = body
  end
end

RSpec.describe 'HttpConnection' do
  let(:connection) { HttpConnection.new(url) }
  describe 'get' do
    let(:url) { "https://www.example.com" }
    subject { connection.communicate do |c| c.get end }
    it 'returns response with status and body' do
      stub_request(:get, 'https://www.example.com').
        to_return(status: 200, body: '{}', headers: {})
      expect( subject.status ).to eq 200
      expect( subject.body ).to eq '{}'
    end
    it 'does not put error log when status code 200, 201, 204' do
      stub_request(:get, 'https://www.example.com').
        to_return(status: 200, body: '{}', headers: {})
      expect{ subject }.not_to output(/.*(WARN|ERROR).*/).to_stdout_from_any_process

      stub_request(:get, 'https://www.example.com').
        to_return(status: 201, body: '{}', headers: {})
      expect{ subject }.not_to output(/.*(WARN|ERROR).*/).to_stdout_from_any_process

      stub_request(:get, 'https://www.example.com').
        to_return(status: 204, body: '{}', headers: {})
      expect{ subject }.not_to output(/.*(WARN|ERROR).*/).to_stdout_from_any_process
    end
    it 'does not retries when ClientError' do
      stub_request(:get, 'https://www.example.com').
      to_raise(Faraday::ClientError.new('message'))
      expect{ subject }.to raise_error CommunicationError
    end
    it 'retries 10 times when system call Timeout' do
      stub_request(:get, 'https://www.example.com').
      to_raise(Errno::ETIMEDOUT).times(10).then.
      to_return(status: 200, body: '{}', headers: {})
      expect{ subject }.to output(/.*Retry.*/).to_stdout_from_any_process
      expect( subject.status ).to eq 200
      expect( subject.body ).to eq '{}'
    end
    it 'retries 10 times when ruby Timeout' do
      stub_request(:get, 'https://www.example.com').
      to_raise(Timeout::Error).times(10).then.
      to_return(status: 200, body: '{}', headers: {})
      expect{ subject }.to output(/.*Retry.*/).to_stdout_from_any_process
      expect( subject.status ).to eq 200
      expect( subject.body ).to eq '{}'
    end
    it 'retries 10 times when faraday Timeout' do
      stub_request(:get, 'https://www.example.com').
      to_raise(Faraday::TimeoutError).times(10).then.
      to_return(status: 200, body: '{}', headers: {})
      expect{ subject }.to output(/.*Retry.*/).to_stdout_from_any_process
      expect( subject.status ).to eq 200
      expect( subject.body ).to eq '{}'
    end
    it 'retries 10 times when ConnectionError' do
      stub_request(:get, 'https://www.example.com').
      to_raise(Faraday::ConnectionFailed).times(10).then.
      to_return(status: 200, body: '{}', headers: {})
      expect{ subject }.to output(/.*Retry.*/).to_stdout_from_any_process
      expect( subject.status ).to eq 200
      expect( subject.body ).to eq '{}'
    end
    it 'raises the last error when retry 11 times' do
      stub_request(:get, 'https://www.example.com').
      to_raise(Errno::ETIMEDOUT).times(3).then.
      to_raise(Timeout::Error).times(3).then.
      to_raise(Faraday::TimeoutError).times(2).then.
      to_raise(Faraday::ConnectionFailed).times(3).then.
      to_return(status: 200, body: '{}', headers: {})
      expect{ subject }.to raise_error CommunicationError
    end
    it 'retries 10 times when to recieves status 500' do
      stub_request(:get, 'https://www.example.com').
      to_return(status: 500, body: '{}', headers: {}).times(10).then.
      to_return(status: 200, body: '{}', headers: {})
      expect{ subject }.to output(/.*Retry.*/).to_stdout_from_any_process
      expect( subject.status ).to eq 200
      expect( subject.body ).to eq '{}'
    end
    it 'finally returns status 500 after 11 times' do
      stub_request(:get, 'https://www.example.com').
      to_return(status: 500, body: '{}', headers: {}).times(11).then.
      to_return(status: 200, body: '{}', headers: {})
      expect{ subject }.to output(/.*Retry.*/).to_stdout_from_any_process
      expect( subject.status ).to eq 500
      expect( subject.body ).to eq '{}'
    end
    it 'does not retries when API 501' do
      stub_request(:get, 'https://www.example.com').
      to_return(status: 501, body: '{}', headers: {}).times(10).then.
      to_return(status: 200, body: '{}', headers: {})
      expect{ subject }.to raise_error ResponseStatusException
    end
  end
end

RSpec.describe 'ArticlesController', type: :request do
  let(:controller) { ArticlesController.new }

  describe 'fetch_via_http' do
    it 'makes list from response body' do
      api_client_mock = double('ApiClient')
      allow(controller).to receive(:api_client).
        and_return(api_client_mock)
      allow(api_client_mock).to receive(:get).
        and_return(
          MockFaradayResponse.new(status: 200, body: '[{"key": "value"}, {"key": "value"}, {"key": "value"}]'),
          MockFaradayResponse.new(status: 200, body: '[]')
        )
      expect( controller.send(:fetch_via_http) ).to eq [{"key"=>"value"}, {"key"=>"value"}, {"key"=>"value"}]
    end
    it 'joints response body till given empty response' do
      api_client_mock = double('ApiClient')
      allow(controller).to receive(:api_client).
        and_return(api_client_mock)
      allow(api_client_mock).to receive(:get).
        and_return(
          MockFaradayResponse.new(status: 200, body: '[{"key": "value"}]'),
          MockFaradayResponse.new(status: 200, body: '[{"key": "value"}, {"key": "value"}]'),
          MockFaradayResponse.new(status: 200, body: '[]')
        )
      expect( controller.send(:fetch_via_http) ).to eq [{"key"=>"value"}, {"key"=>"value"}, {"key"=>"value"}]
    end
    it 'joints till 50 times' do
      api_client_mock = double('ApiClient')
      allow(controller).to receive(:api_client).
        and_return(api_client_mock)
      allow(api_client_mock).to receive(:get).
        and_return(
          MockFaradayResponse.new(status: 200, body: '[{"key": "value"}]'),
        )
      expect( controller.send(:fetch_via_http) ).to eq Array.new(50, {"key"=>"value"})
    end
    it 'raises when response body not json' do
      api_client_mock = double('ApiClient')
      allow(controller).to receive(:api_client).
        and_return(api_client_mock)
      allow(api_client_mock).to receive(:get).
        and_return(MockFaradayResponse.new(status: 200, body: 'aaaaa'))
      expect{ controller.send(:fetch_via_http) }.to raise_error ResponseFormatException
    end
    it 'does not rescue' do
      api_client_mock = double('ApiClient')
      allow(controller).to receive(:api_client).
        and_return(api_client_mock)
      allow(api_client_mock).to receive(:get).
        and_raise(CommunicationError.new)
      expect{ controller.send(:fetch_via_http) }.to raise_error CommunicationError

      allow(api_client_mock).to receive(:get).
        and_raise(ResponseStatusException.new)
      expect{ controller.send(:fetch_via_http) }.to raise_error ResponseStatusException
    end
  end

  describe 'post_via_http' do
    it 'recieve http response' do
      api_client_mock = double('ApiClient')
      allow(controller).to receive(:api_client).
        and_return(api_client_mock)
      allow(api_client_mock).to receive(:post).
        and_return(MockFaradayResponse.new(status: 200, body: '{"id": "1234567890abcd"}'))
      expect{ controller.send(:post_via_http, '{}') }.not_to raise_error
    end
    it 'returns id string' do
      api_client_mock = double('ApiClient')
      allow(controller).to receive(:api_client).
        and_return(api_client_mock)
      allow(api_client_mock).to receive(:post).
        and_return(MockFaradayResponse.new(status: 200, body: '{"id": "1234567890abcd"}'))
      expect( controller.send(:post_via_http, '{}') ).to eq '1234567890abcd'
    end
    it 'raises when response body not json' do
      api_client_mock = double('ApiClient')
      allow(controller).to receive(:api_client).
        and_return(api_client_mock)
      allow(api_client_mock).to receive(:post).
        and_return(MockFaradayResponse.new(status: 200, body: 'aaaa'))
      expect{ controller.send(:post_via_http, '{}') }.to raise_error ResponseFormatException
    end
    it 'raises when response body as object has no id' do
      api_client_mock = double('ApiClient')
      allow(controller).to receive(:api_client).
        and_return(api_client_mock)
      allow(api_client_mock).to receive(:post).
        and_return(MockFaradayResponse.new(status: 200, body: '{"key": "value"}'))
      expect{ controller.send(:post_via_http, '{}') }.to raise_error ResponseFormatException
    end
    it 'does not rescue' do
      api_client_mock = double('ApiClient')
      allow(controller).to receive(:api_client).
        and_return(api_client_mock)
      allow(api_client_mock).to receive(:post).
        and_raise(CommunicationError.new)
      expect{ controller.send(:post_via_http, '{}') }.to raise_error CommunicationError

      allow(api_client_mock).to receive(:post).
        and_raise(ResponseStatusException.new)
      expect{ controller.send(:post_via_http, '{}') }.to raise_error ResponseStatusException
    end
  end

  describe 'delete_via_http' do
    subject { controller.send(:delete_via_http, ["test"]) }
    it 'returns true when receive 204' do
      api_client_mock = double('ApiClient')
      allow(controller).to receive(:api_client).and_return(api_client_mock)
      allow(api_client_mock).to receive(:delete).and_return(MockFaradayResponse.new(status: 204))
      expect( Rails.logger ).not_to receive(:warn).with("Failed to delete test")
      subject
    end
    it 'returns false when recieve 404' do
      api_client_mock = double('ApiClient')
      allow(controller).to receive(:api_client).and_return(api_client_mock)
      allow(api_client_mock).to receive(:delete).and_return(MockFaradayResponse.new(status: 404))
      expect( Rails.logger ).to receive(:warn).with("Failed to delete test")
      subject
    end
    it 'returns false when recieve 500' do
      api_client_mock = double('ApiClient')
      allow(controller).to receive(:api_client).and_return(api_client_mock)
      allow(api_client_mock).to receive(:delete).and_return(MockFaradayResponse.new(status: 500))
      expect( Rails.logger ).to receive(:warn).with("Failed to delete test")
      subject
    end
    it 'does not rescue' do
      api_client_mock = double('ApiClient')
      allow(controller).to receive(:api_client).and_return(api_client_mock)
      allow(api_client_mock).to receive(:delete).and_raise(CommunicationError.new)
      expect{ subject }.to raise_error CommunicationError

      allow(api_client_mock).to receive(:delete).and_raise(ResponseStatusException.new)
      expect{ subject }.to raise_error ResponseStatusException
    end
  end

  describe 'article_params' do
    subject {
      controller.send(:article_params, data) do |params|
        Article.new(params).valid?
      end
    }

    context 'varid given data with url, title, body, user, created_at, updated_at and id in user' do
      let(:data) { API_ITEM_EXAMPLE }
      it { is_expected.to be true }
    end
    context 'varid given data with essentials and extra' do
      example = API_ITEM_EXAMPLE.dup
      example[:dummy] = 'dummy'
      let(:data) { example }
      it { is_expected.to be true }
    end
    context 'invalid if lack of url' do
      let(:data) { API_ITEM_EXAMPLE.reject{|k,v| k==:url} }
      it do
        expect{ subject }.to raise_error ApiUnexpectedAttributesException
      end
    end
    context 'invalid if lack of title' do
      let(:data) { API_ITEM_EXAMPLE.reject{|k,v| k==:title} }
      it do
        expect{ subject }.to raise_error ApiUnexpectedAttributesException
      end
    end
    context 'invalid if lack of body' do
      let(:data) { API_ITEM_EXAMPLE.reject{|k,v| k==:body} }
      it do
        expect{ subject }.to raise_error ApiUnexpectedAttributesException
      end
    end
    context 'invalid if lack of user' do
      let(:data) { API_ITEM_EXAMPLE.reject{|k,v| k==:user} }
      it do
        expect{ subject }.to raise_error PostedByOrganization
      end
    end
    context 'invalid if lack of created_at' do
      let(:data) { API_ITEM_EXAMPLE.reject{|k,v| k==:created_at} }
      it do
        expect{ subject }.to raise_error ApiUnexpectedAttributesException
      end
    end
    context 'invalid if lack of updated_at' do
      let(:data) { API_ITEM_EXAMPLE.reject{|k,v| k==:updated_at} }
      it do
        expect{ subject }.to raise_error ApiUnexpectedAttributesException
      end
    end
    context 'invarid if no id in user' do
      example = API_ITEM_EXAMPLE.deep_dup
      example[:user].delete(:id)
      let(:data) { example }
      it do
        expect{ subject }.to raise_error ApiUnexpectedAttributesException
      end
    end
  end

  describe 'save_buffer' do
    subject { controller.send(:save_buffer) }
    date_expression = Date.today().strftime('%Y-%m-%d')

    context 'working in not lambda' do
      before { ENV['LAMBDA_WORKER'] = nil }
      stock_dir = Rails.root.join('stock', "stock_#{date_expression}.json")
      preserve_dir = Rails.root.join('stock', "preserve_#{date_expression}.json")

      it 'execute store_local method of ObjectBuffer with defined path' do
        object_buffer_stock_mock = double('Object Buffer')
        object_buffer_preserve_mock = double('Object Buffer')
        allow(controller).to receive(:stock_buffer).and_return(object_buffer_stock_mock)
        allow(controller).to receive(:preserve_buffer).and_return(object_buffer_preserve_mock)
        allow(object_buffer_stock_mock).to receive(:store_s3).and_raise(RSpec::Custom::AssertionError)
        allow(object_buffer_preserve_mock).to receive(:store_s3).and_raise(RSpec::Custom::AssertionError)

        expect(object_buffer_stock_mock).to receive(:store_local).
          with(stock_dir).and_return(true)
        expect(object_buffer_preserve_mock).to receive(:store_local).
          with(preserve_dir).and_return(true)
        expect{ subject }.not_to raise_error
      end
      it 'puts log if failed' do
        object_buffer_mock = double('Object Buffer')
        allow(controller).to receive(:stock_buffer).and_return(object_buffer_mock)
        allow(controller).to receive(:preserve_buffer).and_return(object_buffer_mock)
        allow(object_buffer_mock).to receive(:store_local).and_raise(Errno::EACCES)
        expect(Rails.logger).to receive(:error).twice
        subject # call for ensure logger's behaviour
      end
    end

    context 'working in lambda' do
      before { ENV['LAMBDA_WORKER'] = 'lambda' }
      stock_key = "stock/stock_#{date_expression}.json"
      preserve_key = "stock/preserve_#{date_expression}.json"

      it 'execute store_s3 method of ObjectBuffer' do
        object_buffer_stock_mock = double('Object Buffer')
        object_buffer_preserve_mock = double('Object Buffer')
        allow(controller).to receive(:stock_buffer).and_return(object_buffer_stock_mock)
        allow(controller).to receive(:preserve_buffer).and_return(object_buffer_preserve_mock)
        allow(object_buffer_stock_mock).to receive(:store_local).and_raise(RSpec::Custom::AssertionError)
        allow(object_buffer_stock_mock).to receive(:store_s3).and_return(true)
        allow(object_buffer_preserve_mock).to receive(:store_local).and_raise(RSpec::Custom::AssertionError)
        allow(object_buffer_preserve_mock).to receive(:store_s3).and_return(true)
        expect{ subject }.not_to raise_error
      end
      it 'puts log with raw message when store_s3 raised Aws::S3::Errors::ServiceError' do
        object_buffer_stock_mock = double('Object Buffer')
        object_buffer_preserve_mock = double('Object Buffer')
        allow(controller).to receive(:stock_buffer).and_return(object_buffer_stock_mock)
        allow(controller).to receive(:preserve_buffer).and_return(object_buffer_preserve_mock)
        expect(object_buffer_stock_mock).to receive(:store_s3).with(stock_key).and_raise(Aws::S3::Errors::ServiceError.new({}, "message"))
        expect(object_buffer_preserve_mock).to receive(:store_s3).with(preserve_key).and_raise(Aws::S3::Errors::ServiceError.new({}, "message"))
        expect{ subject }.to output(/.*(ERROR).*with message.*/).to_stdout_from_any_process
      end
      it 'puts log with raw message when store_s3 raised Aws::Errors::ServiceError' do
        object_buffer_stock_mock = double('Object Buffer')
        object_buffer_preserve_mock = double('Object Buffer')
        allow(controller).to receive(:stock_buffer).and_return(object_buffer_stock_mock)
        allow(controller).to receive(:preserve_buffer).and_return(object_buffer_preserve_mock)
        expect(object_buffer_stock_mock).to receive(:store_s3).with(stock_key).and_raise(Aws::Errors::ServiceError.new({}, "message"))
        expect(object_buffer_preserve_mock).to receive(:store_s3).with(preserve_key).and_raise(Aws::Errors::ServiceError.new({}, "message"))
        expect{ subject }.to output(/.*(ERROR).*with message.*/).to_stdout_from_any_process
      end
      it 'puts log when store_s3 raised Aws::Sigv4::Errors::MissingCredentialsError' do
        object_buffer_stock_mock = double('Object Buffer')
        object_buffer_preserve_mock = double('Object Buffer')
        allow(controller).to receive(:stock_buffer).and_return(object_buffer_stock_mock)
        allow(controller).to receive(:preserve_buffer).and_return(object_buffer_preserve_mock)
        expect(object_buffer_stock_mock).to receive(:store_s3).with(stock_key).and_raise(Aws::Sigv4::Errors::MissingCredentialsError)
        expect(object_buffer_preserve_mock).to receive(:store_s3).with(preserve_key).and_raise(Aws::Sigv4::Errors::MissingCredentialsError)
        expect{ subject }.to output(/.*(ERROR).*/).to_stdout_from_any_process
      end
      it 'puts log when store_s3 raised Aws::Sigv4::Errors::MissingCredentialsError' do
        object_buffer_stock_mock = double('Object Buffer')
        object_buffer_preserve_mock = double('Object Buffer')
        allow(controller).to receive(:stock_buffer).and_return(object_buffer_stock_mock)
        allow(controller).to receive(:preserve_buffer).and_return(object_buffer_preserve_mock)
        expect(object_buffer_stock_mock).to receive(:store_s3).with(stock_key).and_raise(Aws::Sigv4::Errors::MissingRegionError)
        expect(object_buffer_preserve_mock).to receive(:store_s3).with(preserve_key).and_raise(Aws::Sigv4::Errors::MissingRegionError)
        expect{ subject }.to output(/.*(ERROR).*/).to_stdout_from_any_process
      end
      it 'puts log when store_s3 raised RuntimeError' do
        object_buffer_stock_mock = double('Object Buffer')
        object_buffer_preserve_mock = double('Object Buffer')
        allow(controller).to receive(:stock_buffer).and_return(object_buffer_stock_mock)
        allow(controller).to receive(:preserve_buffer).and_return(object_buffer_preserve_mock)
        expect(object_buffer_stock_mock).to receive(:store_s3).with(stock_key).and_raise(RuntimeError)
        expect(object_buffer_preserve_mock).to receive(:store_s3).with(preserve_key).and_raise(RuntimeError)
        expect{ subject }.to output(/.*(ERROR).*/).to_stdout_from_any_process
      end
    end
  end
  
  describe 'search' do
    subject {controller.search}
    dummy_data = {
      status: 200,
      body: JSON.dump([{
        url: 'https://www.example.com',
        title: 'タイトル',
        body: '# 主題\n## 副題\n本文',
        user: {id: 'test_user'},
        created_at: '2021-04-03T10:25:50+09:00',
        updated_at: '2021-04-03T10:25:50+09:00',
      }]),
      headers: {}
    }
    positive_data = {
      status: 200,
      body: JSON.dump([{
        url: 'https://www.example.com',
        title: 'エラーがでた',
        body: '# 主題\n## 副題\n本文',
        user: {id: 'test_user'},
        created_at: '2021-04-03T10:25:50+09:00',
        updated_at: '2021-04-03T10:25:50+09:00',
      }]),
      headers: {}
    }
    terminater_data = {
      status: 200,
      body: JSON.dump([]),
      headers: {}
    }
    irregular_data = {
      status: 200,
      body: JSON.dump([{
        url: 'https://www.example.com',
      }]),
      headers: {}
    }
    it 'puts log' do
      stub_request(:get, /http.*/).to_return(dummy_data).times(1).then.
        to_return(terminater_data)
      stub_request(:put, /http.*/).to_return(status: 200, headers: {})
      expect{ subject }.to output(/.*Search start$/).to_stdout_from_any_process
    end
    it 'count data size and put them to log' do
      stub_request(:get, /http.*/).to_return(dummy_data).times(20).then.
        to_return(positive_data).times(5).then.
        to_return(terminater_data)
      stub_request(:put, /http.*/).to_return(status: 200, headers: {})
      expect{ subject }.to output(/.*INFO.*Fetch 25 articles\n.*INFO.*5 articles are well in curation/).to_stdout_from_any_process
    end
  end

  describe 'upload' do
    subject {controller.upload}
    it 'puts log' do
      stub_request(:get, /http.*/).to_return(status: 200, headers: {})
      stub_request(:post, /http.*/).to_return(status: 200, headers: {}, body: '{"id":"1234567890abcd"}')
      expect( Rails.logger ).to receive(:info).with(/.*Upload start.*/)
      expect( Rails.logger ).to receive(:info).with(/.*Article will expire at [0-9]{8}T[0-9]{6}.*/)
      subject
    end
  end

  describe 'expire' do

  end
end
