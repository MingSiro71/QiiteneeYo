require 'rails_helper'

# About qiita API HTTP status code
# 200、201、204、400、401、403、404、500の8種類のステータスコードを利用します。
# GETまたはPATCHリクエストに対しては200を、POSTリクエストに対しては201を、
# PUTまたはDELETEリクエストに対しては204を返します。
# 但し、エラーが起きた場合にはその他のステータスコードの中から適切なものを返します。
# So
# [ 200, 201, 204 ].includes code -> OK
# [ 400, 401, 403, 404 ].includes code -> Stop to request
# code == 500 -> Retry
# 

RSpec.describe "Articles", type: :request do
  describe "http_communicate" do
    context "get response 200 from API" do
      allowhttp_connect_mock = double('http_connect')
      expect(Rails.logger).to receive(:info).with(
        "Search start"
      )
    end
    context "api returns 100 article at first and 99 the second" do
      expect(Rails.logger).to receive(:info).with(
        "Search start"
      )
    end
    context "api returns 100 article 50 times" do
      expect(Rails.logger).to receive(:info).with(
        "Search start"
      )
    end
  end
  
  describe "search" do
    context "api returns 99 article" do
      expect(Rails.logger).to receive(:info).with(
        "Search start"
      )
    end
    context "api returns 100 article at first and 99 the second" do
      expect(Rails.logger).to receive(:info).with(
        "Search start"
      )
    end
    context "api returns 100 article 50 times" do
      expect(Rails.logger).to receive(:info).with(
        "Search start"
      )
    end
  end
  discribe "upload" do
    context "do well" do
      expect(Rails.logger).to receive(:info).with(
        "Upload start"
      )
    end
    context "no buffer in instance yet" do
      expect(Rails.logger).to receive(:info).with(
        "Upload start"
      )
    end
    context "buffer does not match format: (draft.make raises Exception)" do
      expect(Rails.logger).to receive(:info).with(
        "Upload start"
      )
    end
  end
end
