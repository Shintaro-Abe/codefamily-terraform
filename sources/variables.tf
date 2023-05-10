#Eメールアドレス
variable "subscription_address" {
  type    = string
  default = "zennzennzenn-SE@gmail.com"
}

#Topicのリソースネーム
variable "topic_name" {
  type    = string
  default = "Api-Notification"
}

#Lambdaのリソースネーム
variable "lambda_name" {
  type    = string
  default = "Api-Lambda-Terraform"
}

#ACMの識別子
variable "certificate_identifer" {
  type    = string
  default = "z26y25x24w23v22u21"
}