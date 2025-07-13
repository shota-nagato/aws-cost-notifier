require 'net/http'
require 'json'
require 'uri'

class ApiClient
  def initialize(base_url = nil)
    @base_url = base_url
  end

  protected

  def post_request(url, payload, headers = {})
    make_request(url, :post, headers, payload)
  end

  def get_request(url, headers = {})
    make_request(url, :get, headers)
  end

  private

  def make_request(url, method, headers = {}, body = nil)
    uri = URI(url)
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = uri.scheme == 'https'

    request = case method
              when :post
                Net::HTTP::Post.new(uri)
              when :get
                Net::HTTP::Get.new(uri)
              else
                raise "Unsupported HTTP method: #{method}"
              end

    headers.each { |key, value| request[key] = value }

    if body
      request.body = body.is_a?(String) ? body : JSON.generate(body)
    end

    response = http.request(request)
    handle_response(response)
  end

  def handle_response(response)
    case response.code
    when '200', '201'
      puts "Request successful: #{response.code}"
      response
    else
      raise "Request failed: #{response.code} #{response.message}"
    end
  end
end
