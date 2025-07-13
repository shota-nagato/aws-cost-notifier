require_relative 'functions/cost_notification'
require_relative 'functions/health_check'
require 'json'

def lambda_handler(event:, context:)
  function_type = event['function_type'] || 'cost_notification'

  case function_type
  when 'cost_notification'
    handle_cost_notification(event)
  when 'health_check'
    handle_health_check(event)
  else
    {
      statusCode: 400,
      body: JSON.generate({
        error: "Unknown function type: #{function_type}",
        available_functions: ['cost_notification', 'health_check']
      })
    }
  end

rescue => e
  puts "Error: #{e.message}"
  puts e.backtrace

  {
    statusCode: 500,
    body: JSON.generate({
      error: e.message
    })
  }
end

def handle_cost_notification(event)
  cost_notification = CostNotification.new
  result = cost_notification.execute

  {
    statusCode: 200,
    body: JSON.generate({
      message: 'Cost notification sent successfully',
      function_type: 'cost_notification',
      daily_total: result[:daily_total],
      monthly_total: result[:monthly_total],
      services_count: result[:services].length
    })
  }
end

def handle_health_check(event)
  health_check = HealthCheck.new
  result = health_check.execute

  {
    statusCode: 200,
    body: JSON.generate({
      message: 'Health check completed successfully',
      function_type: 'health_check',
      status: result[:status],
      timestamp: result[:timestamp]
    })
  }
end
