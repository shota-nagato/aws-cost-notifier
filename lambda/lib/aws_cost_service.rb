require 'aws-sdk-costexplorer'
require 'date'

class AwsCostService
  def initialize(region = 'ap-northeast-1')
    @cost_explorer = Aws::CostExplorer::Client.new(region: region)
  end

  def get_daily_cost(date = Date.today - 1)
    next_day = date + 1
    
    response = @cost_explorer.get_cost_and_usage({
      time_period: {
        start: date.strftime('%Y-%m-%d'),
        end: next_day.strftime('%Y-%m-%d')
      },
      granularity: "DAILY",
      metrics: ["BlendedCost"],
      group_by: [
        {
          type: "DIMENSION",
          key: "SERVICE"
        }
      ]
    })

    parse_daily_response(response)
  end

  def get_monthly_cost(date = Date.today)
    month_start = Date.new(date.year, date.month, 1)
    
    response = @cost_explorer.get_cost_and_usage({
      time_period: {
        start: month_start.strftime('%Y-%m-%d'),
        end: date.strftime('%Y-%m-%d')
      },
      granularity: 'MONTHLY',
      metrics: ['BlendedCost']
    })

    parse_monthly_response(response)
  end

  private

  def parse_daily_response(response)
    daily_total = 0
    service_costs = []

    if response.results_by_time.any?
      response.results_by_time[0].groups.each do |group|
        service = group.keys[0]
        cost = group.metrics['BlendedCost']['amount'].to_f

        if cost > 0
          daily_total += cost
          service_costs << {
            service: service,
            cost: cost
          }
        end
      end
    end

    {
      total: daily_total,
      services: service_costs.sort_by { |item| -item[:cost] }
    }
  end

  def parse_monthly_response(response)
    monthly_total = 0
    if response.results_by_time.any?
      monthly_total = response.results_by_time[0].total['BlendedCost']['amount'].to_f
    end
    monthly_total
  end
end
