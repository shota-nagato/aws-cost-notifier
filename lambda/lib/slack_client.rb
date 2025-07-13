require_relative 'api_client'

class SlackClient < ApiClient
  def initialize(webhook_url = nil)
    @webhook_url = webhook_url || ENV['SLACK_WEBHOOK_URL']
    validate_webhook_url
  end

  def send_message(message)
    post_request(
      @webhook_url,
      message,
      { 'Content-Type' => 'application/json' }
    )
    puts "Message sent to Slack successfully"
  end

  def send_simple_message(text)
    message = { text: text }
    send_message(message)
  end

  def send_blocks_message(text, blocks)
    message = {
      text: text,
      blocks: blocks
    }
    send_message(message)
  end

  private

  def validate_webhook_url
    if @webhook_url.nil? || @webhook_url.empty?
      raise 'SLACK_WEBHOOK_URL environment variable is not set'
    end
  end
end
