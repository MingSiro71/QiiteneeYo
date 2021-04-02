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

    # app_name = File.basename(File.expand_path("#{__dir__}/../"))

    if ENV['LAMBDA_WORKER']=="lambda"
      # config.logger = ActiveSupport::Logger.new("/tmp/#{app_name}/log/#{Rails.env}.log")
      # stdout_logger = ActiveSupport::Logger.new(STDOUT)
      # broadcaster = ActiveSupport::Logger.broadcast(stdout_logger)
      # config.logger.extend(broadcaster)
      config.logger = ActiveSupport::Logger.new(STDOUT)
    else
      config.logger = ActiveSupport::Logger.new(Rails.root.join("log", "#{Rails.env}.log"))      
    end
    config.logger.formatter = proc do |severity, datetime, progname, message|
      "Level:#{severity}, Time:#{datetime}, Message:#{message}\n"
    end
  end
end
