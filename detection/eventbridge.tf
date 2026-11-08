########################################
# Detection for the "Closing the Gap and Detecting It" demo segment.
#
# Maps each step of the chain to its CloudTrail event:
#   AssumeRoleWithWebIdentity -> federated OIDC auth (legit or spoofed)
#   CreateStack               -> the escalation payload being deployed
#   CreateRole / AttachRolePolicy -> the new admin role being created
########################################

variable "alert_email" {
  description = "Email address to receive detection alerts during the demo"
  type        = string
}

resource "aws_sns_topic" "oidc_alerts" {
  name = "${var.name_prefix}-oidc-alerts"
}

resource "aws_sns_topic_subscription" "email" {
  topic_arn = aws_sns_topic.oidc_alerts.arn
  protocol  = "email"
  endpoint  = var.alert_email
}

resource "aws_cloudwatch_event_rule" "oidc_chain_steps" {
  name = "${var.name_prefix}-oidc-chain-steps"

  event_pattern = jsonencode({
    source      = ["aws.sts", "aws.cloudformation", "aws.iam"]
    detail-type = ["AWS API Call via CloudTrail"]
    detail = {
      eventName = [
        "AssumeRoleWithWebIdentity",
        "CreateStack",
        "CreateRole",
        "AttachRolePolicy"
      ]
    }
  })
}

resource "aws_cloudwatch_event_target" "to_sns" {
  rule      = aws_cloudwatch_event_rule.oidc_chain_steps.name
  arn       = aws_sns_topic.oidc_alerts.arn
  target_id = "oidc-alerts"
}

resource "aws_sns_topic_policy" "allow_eventbridge" {
  arn = aws_sns_topic.oidc_alerts.arn

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid       = "AllowEventBridgePublish"
      Effect    = "Allow"
      Principal = { Service = "events.amazonaws.com" }
      Action    = "SNS:Publish"
      Resource  = aws_sns_topic.oidc_alerts.arn
    }]
  })
}

# ---------------------------------------------------------------------
# Demo notes:
#
# 1. This is intentionally broad (fires on every occurrence of these four
#    event names). For the live demo it's useful precisely because it's
#    simple to explain. In a real environment, narrow it: filter
#    AssumeRoleWithWebIdentity to this specific role ARN, and inspect
#    `detail.userIdentity.webIdentityFederationData` / the token's
#    `sub` claim to flag assumptions from repositories you don't
#    recognize — that's the signal that actually distinguishes "legit"
#    from "spoofed" at detection time, not just the event name.
#
# 2. These are all CloudTrail management events, so default trail
#    logging (no extra data-event configuration) is sufficient.
#
# 3. CloudTrail -> EventBridge delivery is not instant. Budget a few
#    minutes during the live demo and have a pre-recorded fallback of
#    the alert arriving, in case timing doesn't cooperate on stage.
# ---------------------------------------------------------------------
