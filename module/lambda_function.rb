class LambdaFunction
  def self.lambda_handler(event:, context:)
    ENV["LAMBDA_WORKER"]="lambda"
    ENV["RAILS_ENV"]="production"
    require_relative 'qiiteneeyo/config/environment'
    require_relative 'qiiteneeyo/lib/tasks/make_draft'
    return { status: "OK", message: "nice!" }
  end
end

if __FILE__==$0
  LambdaFunction::lambda_handler(event:{}, context:{})
end
