#Lambdaモニタリングのポリシー作成
resource "aws_iam_policy" "lambda-logging" {
  name = "lambda-logging"
  path = "/"
  policy = data.aws_iam_policy_document.lambda-logging.json
}

#LambdaのSNSポリシー作成
resource "aws_iam_policy" "lambda-sns" {
  name = "lambda-sns"
  path = "/"
  policy = data.aws_iam_policy_document.lambda-sns.json
}

#Lambdaの実行ロール作成

resource "aws_iam_role" "lambda-role" {
  name = "api-sns"
  assume_role_policy = data.aws_iam_policy_document.lambda-assume-role.json
  managed_policy_arns = [aws_iam_policy.lambda-logging.arn, aws_iam_policy.lambda-sns.arn]
}

#SNSの作成
resource "aws_sns_topic" "cost_sns" {
  name = var.topic_name
  display_name = "Notification"
}

resource "aws_sns_topic_subscription" "subscription" {
  topic_arn = aws_sns_topic.cost_sns.arn
  protocol = "email"
  endpoint = var.subscription_address
}

#API Gatewayの作成
resource "aws_api_gateway_rest_api" "tfsns-api" {
  name = "api-sns"
  endpoint_configuration {
    types = [ "REGIONAL" ]
  }
}

resource "aws_api_gateway_method" "tfsns-method" {
  rest_api_id = aws_api_gateway_rest_api.tfsns-api.id
  resource_id = aws_api_gateway_rest_api.tfsns-api.root_resource_id
  http_method = "ANY"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "tfsns-integration" {
  rest_api_id = aws_api_gateway_rest_api.tfsns-api.id
  resource_id = aws_api_gateway_rest_api.tfsns-api.root_resource_id
  http_method = aws_api_gateway_method.tfsns-method.http_method
  integration_http_method = "ANY"
  type = "AWS_PROXY"
  uri = aws_lambda_function.tfsns-lambda.invoke_arn
}

resource "aws_lambda_permission" "apigw_lambda" {
  statement_id = "AllowExecutionFromAPIGateway"
  action = "lambda:InvokeFunction"
  function_name = aws_lambda_function.tfsns-lambda.function_name
  principal = "apigateway.amazonaws.com"
  source_arn = "arn:aws:execute-api:${local.region}:${local.account_id}:${aws_api_gateway_rest_api.tfsns-api.id}/*/*"
}

#Lambdaの作成
resource "aws_lambda_function" "tfsns-lambda" {
  function_name = var.lambda_name
  filename = "sns.zip"
  role = aws_iam_role.lambda-role.arn
  handler = "sns.handler"
  runtime = "python3.9"
  environment {
    variables = {
      topic: "arn:aws:sns:${local.region}:${local.account_id}:${var.topic_name}"
    }
  }
}

#API Gatewayのデプロイ
resource "aws_api_gateway_deployment" "tfsns-deploy" {
  depends_on = [
    aws_api_gateway_method.tfsns-method, aws_api_gateway_integration.tfsns-integration
  ]
  rest_api_id = aws_api_gateway_rest_api.tfsns-api.id
  stage_name = "prod"
}

#カスタムドメインの設定
resource "aws_api_gateway_domain_name" "tfsns-domain" {
  domain_name = "Your-FQDN"
  regional_certificate_arn = "arn:aws:acm:${local.region}:${local.account_id}:certificate/${var.certificate_identifer}"
  endpoint_configuration {
    types = [ "REGIONAL" ]
  }
}

resource "aws_route53_record" "tfsns-record" {
  name = aws_api_gateway_domain_name.tfsns-domain.domain_name
  type = "A"
  zone_id = "1a2b3c4d5e6f7g"

  alias {
    evaluate_target_health = true
    name = aws_api_gateway_domain_name.tfsns-domain.regional_domain_name
    zone_id = aws_api_gateway_domain_name.tfsns-domain.regional_zone_id
  }
}

resource "aws_api_gateway_base_path_mapping" "domain-mapping" {
  api_id = aws_api_gateway_rest_api.tfsns-api.id
  stage_name = aws_api_gateway_deployment.tfsns-deploy.stage_name
  domain_name = aws_api_gateway_domain_name.tfsns-domain.domain_name
}
