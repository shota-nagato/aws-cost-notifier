require_relative '../lib/slack_client'
require 'json'

class HealthCheck
  def initialize
    @slack_client = SlackClient.new
  end

  def execute
    timestamp = Time.now.strftime('%Y-%m-%d %H:%M:%S')

    message = {
      text: "AWS Lambda Health Check - #{timestamp}",
      blocks: [
        {
          type: "header",
          text: {
            type: "plain_text",
            text: "✅ AWS Lambda Health Check"
          }
        },
        {
          type: "section",
          text: {
            type: "mrkdwn",
            text: "*Status:* Healthy\n*Timestamp:* #{timestamp}\n*Function:* Health Check Lambda"
          }
        }
      ]
    }

    @slack_client.send_message(message)

    {
      status: 'healthy',
      timestamp: timestamp
    }
  end
end
