
ENV['BUNDLE_GEMFILE'] ||= File.expand_path('../Gemfile', __dir__)
app_name = File.basename(File.expand_path("#{__dir__}/../"))

require "bundler/setup" # Set up gems listed in the Gemfile.
require 'bootsnap' # Speed up boot time by caching expensive operations.
if ENV["LAMBDA_WORKER"]=="lambda"
  Bootsnap.setup(cache_dir: "/tmp/#{app_name}/cache/bootsnap/")
else
  Bootsnap.default_setup
end