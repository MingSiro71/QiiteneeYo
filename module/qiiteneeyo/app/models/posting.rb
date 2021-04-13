class ModelStorageError < StandardError
end

class Posting
  DEFAULT_EXPIRATION = 28
  DYNAMO_TABLE = 'Posting'
  DYNAMO_TABLE_PARTITON_KEY = 'id'

  include ActiveModel::Model
  include ActiveModel::Attributes
  attribute :id
  attribute :post_time
  attribute :expired_limit
  validates :id, presence: true
  validates :post_time, absence: true
  validates :expired_limit, absence: true

  def self.create(attributes, options: {})
    posting = self.new(attributes)
    posting.create(options)
  end

  def create(options: {})
    expiration = options[:expiration] || DEFAULT_EXPIRATION
    raise ArgumentError.new('expiration should 0 or larger') if expiration < 0
    client = dynamodb_client
    self.post_time = Time.current.strftime(time_format)
    self.expired_limit = Time.current.since(expiration.day).beginning_of_day.strftime(time_format)
    begin
      client.put_item(
        table_name: DYNAMO_TABLE, 
        item: self.attributes
      )
    rescue Aws::DynamoDB::Errors::ServiceError, Aws::Errors::ServiceError => e
      Rails.logger.error("AWS DynamoDB service error #{e.class.name} with message, #{e.message}")
      raise ModelStorageError.new
    rescue Aws::Sigv4::Errors::MissingCredentialsError, Aws::Sigv4::Errors::MissingRegionError => e
      Rails.logger.error(e.class.name)
      raise ModelStorageError.new
    rescue RuntimeError => e
      raise ModelStorageError.new
    end
    self.expired_limit
  end

  def self.expire
    posting = self.new({})
    posting.expire
  end

  def expire
    expired_ids = []
    begin
      client = dynamodb_client
      result = client.scan(
        table_name: DYNAMO_TABLE,
        projection_expression: DYNAMO_TABLE_PARTITON_KEY,
        filter_expression: '#elim < :time',
        expression_attribute_names: { '#elim' => 'expired_limit' },
        expression_attribute_values: {
          ':time' => Time.current.strftime(time_format)
        }
      )
      result.items.each do |item|
        partition_key = item[DYNAMO_TABLE_PARTITON_KEY]
        client.delete_item(
          table_name: DYNAMO_TABLE,
          key: { DYNAMO_TABLE_PARTITON_KEY => partition_key }
        )
        expired_ids.append(partition_key)
      end
    rescue Aws::DynamoDB::Errors::ServiceError, Aws::Errors::ServiceError => e
      Rails.logger.error("AWS DynamoDB service error #{e.class.name} with message, #{e.message}")
      raise ModelStorageError.new
    rescue Aws::Sigv4::Errors::MissingCredentialsError, Aws::Sigv4::Errors::MissingRegionError => e
      Rails.logger.error(e.class.name)
      raise ModelStorageError.new
    rescue RuntimeError => e
      raise ModelStorageError.new
    end
    expired_ids
  end

  private
  def dynamodb_client
    Aws::DynamoDB::Client.new(
      region: ENV['QIITENEEYO_DYNAMODB_REGION']
    )
  end
  def time_format
    '%Y%m%dT%H%M%S'
  end
end