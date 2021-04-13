# Use lambda mode just so as to print log into STDOUT
ENV['LAMBDA_WORKER']="lambda"

require 'rails_helper'
require 'byebug'

initial_tz = ENV['TZ']

RSpec.describe "Application" do
  describe "customize log" do
    before { ENV['TZ']='Asia/Tokyo' }
    after { ENV['TZ']=initial_tz }
    it "is test" do
      expect{ Rails.logger.info("This is test log.") }.to output(
        /Level:INFO, Time:[0-9]{4}-[0-9]{2}-[0-9]{2} [0-9]{2}:[0-9]{2}:[0-9]{2} \+0900, Message:This is test log\./
      ).to_stdout_from_any_process
    end
  end
end
