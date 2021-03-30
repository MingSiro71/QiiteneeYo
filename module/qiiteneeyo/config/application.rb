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
    config.logger = ActiveSupport::Logger.new(Rails.root.join("log", "#{Rails.env}.log"))
    if ENV['LAMBDA_WORKER']=="lambda"
      stdout_logger = ActiveSupport::Logger.new(STDOUT)
      broadcaster = ActiveSupport::Logger.broadcast(stdout_logger)
      config.logger.extend(broadcaster)
    end
    config.logger.formatter = proc do |severity, datetime, progname, message|
      "Level:#{severity}, Time:#{datetime}, Message:#{message}\n"
    end
  end
end
