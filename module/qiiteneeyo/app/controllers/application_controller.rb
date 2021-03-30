class ApplicationController < ActionController::API
  def lambda_worker?
    ENV['LAMBDA_WORKER']=="lambda"
  end
end
