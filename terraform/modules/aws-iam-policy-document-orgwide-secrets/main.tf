locals {
  policy_name = "OrgwideSecretsReader"
}

data "aws_iam_policy_document" "orgwide-secrets-policy" {
  statement {
    actions = [
      "secretsmanager:GetSecretValue",
    ]

    // HACK hard-coding because these live in terraform/accounts/czi-si
    resources = [
      "arn:aws:secretsmanager:us-west-2:626314663667:secret:si-prod-crowdstrike_falcon-ZfkCrB",          # Crowdstrike
      "arn:aws:secretsmanager:us-west-2:626314663667:secret:si-prod-datadog_api_key-nef6eE",             # Datadog
      "arn:aws:secretsmanager:us-west-2:626314663667:secret:si-prod-github_images_deploy_key-6mQ2pH",    # Github Images Deploy Key
      "arn:aws:secretsmanager:us-west-2:626314663667:secret:si-prod-osquery_fleet_enroll_secret-MxVmNx", # Osquery fleet enroll secret
    ]
  }

  statement {
    actions = [
      "kms:Decrypt",
      "kms:DescribeKey",
    ]

    // HACK hard-coding because these live in terraform/accounts/czi-si
    resources = [
      "arn:aws:kms:us-west-2:626314663667:key/65d38e80-a6f9-4764-918c-dd0b00634902", # Crowdstrike
      "arn:aws:kms:us-west-2:626314663667:key/0b66522e-ed82-41b2-aa67-d15822093c38", # Datadog
      "arn:aws:kms:us-west-2:626314663667:key/93a3dcab-f929-4119-866e-36b296cc6a4a", # Github Images Deploy Key
      "arn:aws:kms:us-west-2:626314663667:key/346b56b6-cad6-4d7f-bd73-76fcffcf916f", # Osquery fleet enroll secret
    ]
  }

  statement {
    actions = ["s3:GetObject"]

    // HACK hard-coding because these live in terraform/accounts/czi-si
    resources = ["arn:aws:s3:::shared-infra-prod-assets/*"]
  }

  statement {
    actions = ["s3:ListBucket"]

    // HACK hard-coding because these live in terraform/accounts/czi-si
    resources = ["arn:aws:s3:::shared-infra-prod-assets"]
  }
}
