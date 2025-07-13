# AWS Multi-Function Lambda

AWS のコスト通知機能を含む、汎用的な複数機能対応の Lambda 関数プロジェクトです。

## 機能

### 現在利用可能な機能

1. **コスト通知 (cost_notification)**

   - 毎日の AWS コストを Slack に通知
   - 月次累計コストの表示
   - サービス別コスト内訳（上位 5 サービス）

2. **健康チェック (health_check)**
   - Lambda 関数の動作確認
   - 定期的な健康チェック通知

## プロジェクト構成

```
lambda/
├── function.rb              # メインのLambda関数エントリーポイント
├── lib/                     # 共通ライブラリ
│   ├── api_client.rb        # 汎用HTTP APIクライアント基底クラス
│   ├── slack_client.rb      # Slack専用クライアント
│   └── aws_cost_service.rb  # AWS Cost Explorer サービス
├── functions/               # 個別機能
│   ├── cost_notification.rb # コスト通知機能
│   └── health_check.rb      # 健康チェック機能
├── Gemfile                  # Ruby依存関係
└── Gemfile.lock
```

## 使用方法

### 1. 環境変数の設定

```bash
export SLACK_WEBHOOK_URL="your-slack-webhook-url"
```

### 2. Terraform でのデプロイ

```bash
# 初期化
terraform init

# プランの確認
terraform plan

# デプロイ
terraform apply
```

### 3. 手動実行（テスト用）

```bash
# コスト通知を実行
aws lambda invoke \
  --function-name multi-function-lambda \
  --payload '{"function_type": "cost_notification"}' \
  response.json

# 健康チェックを実行
aws lambda invoke \
  --function-name multi-function-lambda \
  --payload '{"function_type": "health_check"}' \
  response.json
```

## 新しい機能の追加方法

### 1. 新しい機能クラスの作成

```ruby
# lambda/functions/new_feature.rb
require_relative '../lib/slack_client'

class NewFeature
  def initialize
    @slack_client = SlackClient.new
  end

  def execute
    # 機能の実装
    result = perform_task()

    # Slack通知（必要に応じて）
    @slack_client.send_simple_message("新機能が実行されました")

    result
  end

  private

  def perform_task
    # 実際の処理
  end
end
```

### 2. メイン関数への追加

```ruby
# lambda/function.rb に追加
require_relative 'functions/new_feature'

# case文に追加
when 'new_feature'
  handle_new_feature(event)

# ハンドラー関数の追加
def handle_new_feature(event)
  new_feature = NewFeature.new
  result = new_feature.execute

  {
    statusCode: 200,
    body: JSON.generate({
      message: 'New feature executed successfully',
      function_type: 'new_feature',
      result: result
    })
  }
end
```

### 3. EventBridge スケジュール設定（必要に応じて）

```hcl
# main.tf に追加
resource "aws_cloudwatch_event_rule" "new_feature_schedule" {
  name        = "new-feature-schedule"
  description = "Schedule for new feature"

  schedule_expression = "cron(0 12 * * ? *)"  # 毎日正午
}

resource "aws_cloudwatch_event_target" "new_feature_target" {
  rule      = aws_cloudwatch_event_rule.new_feature_schedule.name
  target_id = "NewFeatureTarget"
  arn       = aws_lambda_function.multi_function_lambda.arn

  input = jsonencode({
    function_type = "new_feature"
  })
}
```

## 設計の利点

1. **単一責任の原則**: 各機能が独立したクラスとして実装
2. **再利用性**: 共通ライブラリ（ApiClient、SlackClient）の活用
3. **拡張性**: 新しい機能を簡単に追加可能
4. **保守性**: 機能ごとに分離された明確な構造
5. **テスト容易性**: 各コンポーネントが独立してテスト可能

## 必要な権限

- Cost Explorer API へのアクセス権限
- Lambda 実行権限
- EventBridge 実行権限
- CloudWatch Logs 書き込み権限
