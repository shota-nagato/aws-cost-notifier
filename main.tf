terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region  = "ap-northeast-1"
  profile = "default"
}

data "archive_file" "lambda_function" {
  type        = "zip"
  source_dir  = "${path.module}/lambda"
  output_path = "${path.module}/lambda.zip"
}

resource "aws_iam_role" "lambda_role" {
  name = "cost-notification-lambda-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "lambda__basic_execution" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_role_policy" "cost_explorer_policy" {
  name = "cost-explorer-policy"
  role = aws_iam_role.lambda_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ce:GetCostAndUsage",
          "ce:GetDimensionValues",
          "ce:GetReservationCoverage",
          "ce:GetReservationPurchaseRecommendation",
          "ce:GetReservationUtilization",
          "ce:GetUsageReport",
          "ce:DescribeCostCategoryDefinition",
          "ce:GetRightsizingRecommendation"
        ]
        Resource = "*"
      }
    ]
  })
}

resource "aws_lambda_function" "cost_notification" {
  filename      = data.archive_file.lambda_function.output_path
  function_name = "cost-notification"
  role          = aws_iam_role.lambda_role.arn
  handler       = "function.lambda_handler"
  runtime       = "ruby3.2"
  timeout       = 60

  source_code_hash = data.archive_file.lambda_function.output_base64sha256

  environment {
    variables = {
      SLACK_WEBHOOK_URL = var.slack_webhook_url
    }
  }
}

resource "aws_iam_role" "eventbridge_role" {
  name = "eventbridge-lambda-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "events.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_role_policy" "eventbridge_lambda_policy" {
  name = "eventbridge-lambda-policy"
  role = aws_iam_role.eventbridge_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "lambda:InvokeFunction"
        ]
        Resource = aws_lambda_function.cost_notification.arn
      }
    ]
  })
}

resource "aws_cloudwatch_event_rule" "cost_notification_schedule" {
  name        = "cost-notification-schedule"
  description = "Daily cost notification schedule"

  schedule_expression = "cron(0 0 * * ? *)"
}

resource "aws_cloudwatch_event_target" "cost_notification_target" {
  rule      = aws_cloudwatch_event_rule.cost_notification_schedule.name
  target_id = "CostNotificationTarget"
  arn       = aws_lambda_function.cost_notification.arn

  input = jsonencode({
    function_type = "cost_notification"
  })
}

resource "aws_lambda_permission" "allow_eventbridge_cost_notification" {
  statement_id  = "AllowExecutionFromEventBridge"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.cost_notification.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.cost_notification_schedule.arn
}
