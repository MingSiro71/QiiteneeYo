require_relative "boot"

require "rails"

require "active_model/railtie"
require "active_job/railtie"
require "action_controller/railtie"
#require "action_cable/engine"
require "rails/test_unit/railtie"

Bundler.require(:default, Rails.env)

module Qiiteneeyo
  class Application < Rails::Application
    # Initialize configuration defaults for originally generated Rails version.
    config.load_defaults 6.1

    config.time_zone = "Tokyo"

    config.api_only = true

    if ENV['LAMBDA_WORKER']=="lambda"
      config.logger = ActiveSupport::Logger.new($stdout)
    else
      config.logger = ActiveSupport::Logger.new(Rails.root.join("log", "#{Rails.env}.log"))
    end
    config.logger.formatter = proc do |severity, datetime, progname, message|
      "Level:#{severity}, Time:#{datetime}, Message:#{message}\n"
    end
  end
end
