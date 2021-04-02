class CommunicationError < Exception
end

class ResposeFormatException < Exception
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
    def paging_max() 50 end
    def available_max_per_page() 100 end
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
      retry_statuses: ApiRequestProfile::possible_statuses,
      methods: [],
      retry_if: ->(_env, _exception) {
        if _env.status.to_i >= 400
          Rails.logger.warn("Communication error status=#{_env.status}")
          return true
        else
          return false
        end
      },
      retry_block: -> (_env, options, retries, _exception) {
        Rails.logger.warn("Communication error exception=#{_exception.to_s}")
        Rails.logger.warn("Retry communicate with #{_env.url.to_s}")
      }
    }
    self.request(:retry, retry_options)
    block.call(self)
  end
end

class ArticlesController < ApplicationController  
  def search
    logger.info("Search start")
    @stock_buffer = ObjectBuffer.new
    @preserve_buffer = ObjectBuffer.new
    list = fetch_via_http
    list.each do |data|
      article_params data do |params|
        article = Article.new(params)
        @stock_buffer.append article.attributes if article.curate
        @preserve_buffer.append article.attributes
      end
    end
    logger.info("Fetch #{@preserve_buffer.size} articles")
    logger.info("#{@stock_buffer.size} articles are well in curation")
    begin
      save_buffer
    rescue => e
      logger.warn("Failed to save buffer, #{e.to_s}")
    end
  end

  def upload
    logger.info("Upload start")
    stock_count = @stock_buffer ? @stock_buffer.size : nil
    preserve_count = @preserve_buffer ? @preserve_buffer.size : nil
    post_via_http @stock_buffer.to_draft.publish(stock_count: stock_count, preserve_count: preserve_count,)
  end

  private
  def http_connection(url, &block)
    connection = HttpConnection.new url
    if block_given?
      block.call(connection)
    else
      connection
    end
  end

  def fetch_via_http
    url = "#{ApiRequestProfile::base_url}/items"    
    list = (1..ApiRequestProfile::paging_max).reduce([]) do |acc, page|
      connection = http_connection url do |conn|
        conn.headers = {
          Authorization: ApiRequestProfile::access_token,
          Accept: ApiRequestProfile::data_type
        }
        conn.params = {
          page: nil,
          per_page: ApiRequestProfile::available_max_per_page,
          query: ApiRequestProfile::search_query
        }
        conn
      end
      connection.params[:page] = page
      begin
        response = connection.communicate do |com|
          com.get
        end
        list = JSON.parse(response.body)
      rescue CommunicationError => e
        logger.error("Failed to communicate external API, #{e.to_s}")
        raise CommunicationError e
      rescue ResposeFormatException => e
        logger.error("External API returns odd data, #{e.to_s}")
        raise ResposeFormatException e
      end
      break acc if list.size==0
      acc + list
    end
  end

  STOCK_NAME = "stock_#{Date.today().strftime('%Y-%m-%d')}.json"
  PRESERVE_NAME = "preserve_#{Date.today().strftime('%Y-%m-%d')}.json"
  LOCAL_STOCK_PATH = Rails.root.join('stock', STOCK_NAME)
  LOCAL_PRESERVE_PATH = Rails.root.join('stock', PRESERVE_NAME)
  S3_STOCK_KEY = "stock/#{STOCK_NAME}"
  S3_PRESERVE_KEY = "stock/#{PRESERVE_NAME}"

  def save_buffer
    if lambda_worker?
      @stock_buffer.store_s3 S3_STOCK_KEY
      @preserve_buffer.store_s3 S3_PRESERVE_KEY
    else
      @stock_buffer.store_local LOCAL_STOCK_PATH
      @preserve_buffer.store_local LOCAL_PRESERVE_PATH
    end
    true
  end

  def post_via_http(draft)
    url = "#{ApiRequestProfile::base_url}/items"
    connection = http_connection url do |conn|
      conn.headers = {
        Authorization: ApiRequestProfile::access_token,
        "Content-Type"=> ApiRequestProfile::data_type
      }
      conn
    end
    begin
      response = connection.communicate do |com|
        com.post do |request|
          request.body = draft
        end
      end
    rescue CommunicationError => e
      logger.error("Failed to communicate external API, #{e.to_s}")
      raise CommunicationError e
    end
  end

  def article_params(data = nil)
    return false unless url = data['url'] || data[:url]
    return false unless title = data['title'] || data[:title]
    return false unless body = data['body'] || data[:body]
    return false unless _user = data['user'] || data[:user]
    return false unless user = _user['id'] || _user[:id]
    return false unless created_at = data['created_at'] || data[:created_at]
    return false unless updated_at = data['updated_at'] || data[:updated_at]
    if block_given?
      yield(
        { url: url,
          title: title,
          body: body,
          user: user,
          created_at: created_at,
          updated_at: updated_at
        }
      )
    else 
      return {
        url: url,
        title: title,
        body: body,
        user: user,
        created_at: created_at,
        updated_at: updated_at
      }
    end
  end
end
