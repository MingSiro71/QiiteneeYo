class CommunicationError < StandardError
end
class ResponseFormatException < StandardError
end
class ResponseStatusException < StandardError
end
class ApiUnexpectedAttributesException < StandardError
end

# Avoid format exception posted by non user 
class PostedByOrganization < StandardError
end

module QueryRule
  class << self
    def recent(days)
      begin
        "created:>#{(Time.current - days.day).strftime('%Y-%m-%d')}"
      rescue
        return nil
      end
    end
  end
end

module ApiRequestProfile
  class << self
    def base_url() "https://qiita.com/api/v2" end
    def paging_max() 1 end
    def available_max_per_page() 1 end
    def access_token() "Bearer #{ENV['QIITA_ACCESS_TOKEN']}" end
    def data_type() "application/json" end
    def search_query() QueryRule::recent(7) end
    def possible_statuses() [200, 201, 204, 400, 401, 403, 404, 500] end
  end
end

module HttpCommunicateProfile
  class << self
    def retry_max() 10 end
    def retry_interval() 0.5 end
    def retry_interval_randomness() 0 end
    def backoff_factor() 0.25 end
  end
end

class HttpConnection < Faraday::Connection
  def communicate(&block)
    retry_options = {
      max: HttpCommunicateProfile::retry_max,
      interval: HttpCommunicateProfile::retry_interval,
      interval_randomness: HttpCommunicateProfile::retry_interval_randomness,
      backoff_factor: HttpCommunicateProfile::backoff_factor,
      exceptions: [
        Errno::ETIMEDOUT, Timeout::Error, Faraday::TimeoutError,
        Faraday::ConnectionFailed, Faraday::ClientError, Faraday::RetriableResponse
      ],
      retry_statuses: ApiRequestProfile::possible_statuses,
      methods: [],
      retry_if: ->(_env, _exception) {
        if _exception.class == Faraday::ClientError
          Rails.logger.error("Unexpected error from faraday, #{_exception.to_s}")
          return false
        elsif _exception.class != Faraday::RetriableResponse
          Rails.logger.error("Connection error from faraday, #{_exception.to_s}")
          return true
        elsif _env.status==500
          Rails.logger.warn("HTTP status #{_env.status}")
          return true
        elsif ![200, 201, 204].include?_env.status
          Rails.logger.warn("HTTP status #{_env.status}")
          return false
        end
      },
      retry_block: -> (_env, options, retries, _exception) {
        Rails.logger.warn("Retry #{retries}")
      }
    }
    self.request(:retry, retry_options)
    begin
      response = block.call(self)
    rescue Errno::ETIMEDOUT, Timeout::Error, Faraday::TimeoutError, Faraday::ConnectionFailed, Faraday::ClientError => e
      raise CommunicationError
    end
    if !response.respond_to?(:status)
      raise CommunicationError
    elsif !ApiRequestProfile::possible_statuses.include?(response.status)
      raise ResponseStatusException
    end
    response
  end
end

class ApiClient
  def initialize(url: 'http://www.example.com')
    @connection = HttpConnection.new(url)
  end

  def get(headers: {}, params: {})
    connection = @connection
    connection.headers = headers
    connection.params = params
    response = connection.communicate do |com|
      com.get
    end
  end

  def post(headers: {}, body: nil)
    connection = @connection
    connection.headers = headers
    response = connection.communicate do |com|
      com.post do |request|
        request.body = body
      end
    end
  end

  def delete(headers: {})
    connection = @connection
    connection.headers = headers
    response = connection.communicate do |com|
      com.delete
    end
  end
end

class ArticlesController < ApplicationController
  attr_reader :stock_buffer, :preserve_buffer

  def initialize
    super
    @stock_buffer = ObjectBuffer.new
    @preserve_buffer = ObjectBuffer.new
  end

  def search
    logger.info("Search start")
    print "Search start"
    puts "Search start"
    datalist = fetch_via_http
    datalist.each do |data|
      begin
        article_params data do |params|
          article = Article.new(params)
          @stock_buffer.append article.attributes if article.curate
          @preserve_buffer.append article.attributes
        end
      rescue PostedByOrganization => e
        logger.info('Ignore article from organization')
      end
    end
    logger.info("Fetch #{@preserve_buffer.size} articles")
    logger.info("#{@stock_buffer.size} articles are well in curation")
    save_buffer
  end

  def upload
    logger.info("Upload start")
    stock_count = self.stock_buffer.size
    preserve_count = self.preserve_buffer.size
    post_id = post_via_http @stock_buffer.to_draft.publish(stock_count: stock_count, preserve_count: preserve_count,)
    expire_limit = Posting.create({ id: post_id })
    logger.info("Article will expire at #{expire_limit}")
  end

  def expire
    expired_ids = Posting.expire
    delete_via_http(expired_ids)
  end

  private
  def api_client(url)
    return ApiClient.new(url: url)
  end

  def fetch_via_http
    url = "#{ApiRequestProfile::base_url}/items"    
    headers = {
      Authorization: ApiRequestProfile::access_token,
      Accept: ApiRequestProfile::data_type
    }
    params = {
      page: nil,
      per_page: ApiRequestProfile::available_max_per_page,
      query: ApiRequestProfile::search_query
    }
    datalist = (1..ApiRequestProfile::paging_max).reduce([]) do |acc, page|
      client = api_client(url)
      params[:page] = page
      response = client.get(headers: headers, params: params)
      begin
        datalist = JSON.parse(response.body)
      rescue JSON::ParserError => e
        logger.error("External API returns odd data, #{e.to_s}")
        raise ResponseFormatException.new
      end
      break acc if datalist.size==0
      acc + datalist
    end
  end

  STOCK_NAME = "stock_#{Time.current.strftime('%Y-%m-%d')}.json"
  PRESERVE_NAME = "preserve_#{Time.current.strftime('%Y-%m-%d')}.json"
  LOCAL_STOCK_PATH = Rails.root.join('stock', STOCK_NAME)
  LOCAL_PRESERVE_PATH = Rails.root.join('stock', PRESERVE_NAME)
  S3_STOCK_KEY = "stock/#{STOCK_NAME}"
  S3_PRESERVE_KEY = "stock/#{PRESERVE_NAME}"

  def post_via_http(draft)
    url = "#{ApiRequestProfile::base_url}/items"
    headers = {
      Authorization: ApiRequestProfile::access_token,
      "Content-Type"=> ApiRequestProfile::data_type
    }
    client = api_client(url)
    response = client.post(headers: headers, body: draft)
    begin
      result = JSON.parse(response.body)
      raise KeyError.new('id not found') unless post_id = result['id']
    rescue JSON::ParserError, KeyError => e
      logger.error("External API returns odd data, #{e.to_s}")
      raise ResponseFormatException.new
    end
    post_id
  end

  def delete_via_http(ids)
    headers = { Authorization: ApiRequestProfile::access_token }
    ids.each do |id|
      url = "#{ApiRequestProfile::base_url}/items/#{id}"
      client = api_client(url)
      response = client.delete(headers: headers)
      logger.warn("Failed to delete #{id}") unless response.status == 204
    end
  end

  def article_params(data = nil, &block)
    unless block
      return false
    else
      begin
        raise KeyError unless url = data['url'] || data[:url]
        raise KeyError unless title = data['title'] || data[:title]
        raise KeyError unless body = data['body'] || data[:body]
        raise PostedByOrganization unless _user = data['user'] || data[:user]
        raise KeyError unless user = _user['id'] || _user[:id]
        raise KeyError unless created_at = data['created_at'] || data[:created_at]
        raise KeyError unless updated_at = data['updated_at'] || data[:updated_at]
      rescue KeyError
        logger.error("Unexpected API response data attributes #{data.to_s}")
        raise ApiUnexpectedAttributesException
      end
      yield(
        { 
          url: url,
          title: title,
          body: body,
          user: user,
          created_at: created_at,
          updated_at: updated_at
        }
      )
    end
  end

  def save_buffer
    status = true
    [
      { buffer: self.stock_buffer, key: STOCK_NAME },
      { buffer: self.preserve_buffer, key: PRESERVE_NAME }
    ].each do |target|
      if lambda_worker?
        status = false unless save_buffer_to_s3(target)
      else
        status = false unless save_buffer_to_local(target)
      end
    end
    status
  end

  def save_buffer_to_s3(target)
    begin
      target[:buffer].store_s3("stock/#{target[:key]}")
    rescue Aws::S3::Errors::ServiceError, Aws::Errors::ServiceError => e
      logger.error("Failed to save buffer with #{e.class.name} with message, #{e.message}")
      return false
    rescue Aws::Sigv4::Errors::MissingCredentialsError, Aws::Sigv4::Errors::MissingRegionError, RuntimeError => e
      logger.error("Failed to save buffer with #{e.class.name}")
      return false
    end
    return true
  end
  
  def save_buffer_to_local(target)
    begin
      target[:buffer].store_local Rails.root.join('stock', target[:key])
    rescue => e
      logger.error("Failed to save buffer with #{e.class.name}")
      return false
    end
    return true
  end
end
