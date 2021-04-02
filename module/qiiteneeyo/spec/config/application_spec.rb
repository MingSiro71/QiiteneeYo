require 'rails_helper'
gem 'byebug'


RSpec.describe "Application" do
  describe "customize log" do
    it "is test" do
      expect{ Rails.logger.info("This is test log.") }.to output(
        /Level:INFO, Time:[0-9]{4}-[0-9]{2}-[0-9]{2} [0-9]{2}:[0-9]{2}:[0-9]{2} \+0900, Message:This is test log\./
      ).to_stdout_from_any_process
    end
  end
end
