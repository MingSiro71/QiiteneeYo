class ApplicationBatch
  # def initialize
  #   @logger ||= begin
  #     logger = ActiveSupport::Logger.new(Rails.root.join('log', "batch_#{Rails.env}.log"))
  #     logger.formatter = Logger::Formatter.new
  #     logger.datetime_format = '%Y-%m-%d %H:%M:%S'
  #     srdout_logger = ActiveSupport::Logger.new(STDOUT)
  #     broadcaster = ActiveSupport::Logger.broadcast(srdout_logger)
  #     logger.extend(broadcaster)
  #   end
  # end
end
