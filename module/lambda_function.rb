def lambda_handler(event:, context:)
  ENV["LAMBDA_WORKER"]="lambda"
  ENV["RAILS_ENV"]="production"
  # ENV["RAILS_ENV"]="test"
  require_relative 'qiiteneeyo/config/environment'
  require_relative 'qiiteneeyo/lib/tasks/make_draft'
end

lambda_handler(event:{}, context:{})
