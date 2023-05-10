data "aws_region" "current" {}
locals{
  region = data.aws_region.current.name
}
output "region" {
  value = local.region
}

data "aws_caller_identity" "current" {}
locals{
  account_id = data.aws_caller_identity.current.account_id
}
output "account_id" {
  value = local.account_id
}
data "archive_file" "lambda" {
  type        = "zip"
  source_file = "sns.py"
  output_path = "sns.zip"
}

#Lambdaの実行ロールにアタッチするポリシー
data "aws_iam_policy_document" "lambda-logging" {
  statement {
    effect = "Allow"
    actions = [
      "logs:CreateLogGroup",
      "logs:CreateLogStream",
      "logs:PutLogEvents"
    ]
    resources = [ "arn:aws:logs:${local.region}:${local.account_id}:log-group:/aws/lambda/${var.lambda_name}:*" ]
  }
}

data "aws_iam_policy_document" "lambda-sns" {
  statement {
    effect = "Allow"
    actions = [
      "sns:Publish"
    ]
    resources = [ "arn:aws:sns:${local.region}:${local.account_id}:${var.topic_name}" ]
  }
}

data "aws_iam_policy_document" "lambda-assume-role" {
  statement {
    actions = [ "sts:AssumeRole" ]
    principals {
      type = "Service"
      identifiers = [ "lambda.amazonaws.com" ]
    }
  }
}