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

# Lambda関数のパッケージ
data "archive_file" "lambda_function" {
  type        = "zip"
  source_dir  = "${path.module}/lambda"
  output_path = "${path.module}/lambda.zip"
}

# Lambda実行用のIAMロール
resource "aws_iam_role" "lambda_role" {
  name = "multi-function-lambda-role"

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

# 基本的なLambda実行権限
resource "aws_iam_role_policy_attachment" "lambda_basic_execution" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

# Cost Explorer用のポリシー
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

# メインのLambda関数（複数機能対応）
resource "aws_lambda_function" "multi_function_lambda" {
  filename      = data.archive_file.lambda_function.output_path
  function_name = "multi-function-lambda"
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

# EventBridge用のIAMロール
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

# EventBridgeがLambdaを実行するための権限
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
        Resource = aws_lambda_function.multi_function_lambda.arn
      }
    ]
  })
}

# コスト通知用のEventBridgeルール（毎日午前9時に実行）
resource "aws_cloudwatch_event_rule" "cost_notification_schedule" {
  name        = "cost-notification-schedule"
  description = "Daily cost notification schedule"

  schedule_expression = "cron(0 0 * * ? *)" # 毎日午前9時 (UTC)
}

# EventBridgeルールのターゲット（コスト通知）
resource "aws_cloudwatch_event_target" "cost_notification_target" {
  rule      = aws_cloudwatch_event_rule.cost_notification_schedule.name
  target_id = "CostNotificationTarget"
  arn       = aws_lambda_function.multi_function_lambda.arn

  input = jsonencode({
    function_type = "cost_notification"
  })
}

# Lambda関数がEventBridgeから実行されることを許可
resource "aws_lambda_permission" "allow_eventbridge_cost_notification" {
  statement_id  = "AllowExecutionFromEventBridge"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.multi_function_lambda.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.cost_notification_schedule.arn
}

# 健康チェック用のEventBridgeルール（毎時実行）
resource "aws_cloudwatch_event_rule" "health_check_schedule" {
  name        = "health-check-schedule"
  description = "Hourly health check schedule"

  schedule_expression = "cron(0 * * * ? *)" # 毎時実行
}

# EventBridgeルールのターゲット（健康チェック）
resource "aws_cloudwatch_event_target" "health_check_target" {
  rule      = aws_cloudwatch_event_rule.health_check_schedule.name
  target_id = "HealthCheckTarget"
  arn       = aws_lambda_function.multi_function_lambda.arn

  input = jsonencode({
    function_type = "health_check"
  })
}

# Lambda関数がEventBridgeから実行されることを許可（健康チェック）
resource "aws_lambda_permission" "allow_eventbridge_health_check" {
  statement_id  = "AllowExecutionFromEventBridgeHealthCheck"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.multi_function_lambda.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.health_check_schedule.arn
}
