# Copyright 2025 Automate the Cloud Inc.
# SPDX-License-Identifier: Apache-2.0

# Creates the table's KMS keys in the same run as the table, so their ARNs are unknown at
# plan time. Runs against mocked providers only.

terraform {
  required_version = ">= 1.9"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 6.44"
    }
  }
}

provider "aws" {
  region = "us-east-1"
}

provider "aws" {
  alias  = "us_west_2"
  region = "us-west-2"
}

resource "aws_kms_key" "table" {
  description         = "Test key for the table"
  enable_key_rotation = true
}

resource "aws_kms_key" "replica" {
  provider            = aws.us_west_2
  description         = "Test key for the replica"
  enable_key_rotation = true
}

module "table" {
  source = "../../.."

  details = {
    scope       = "Automate the Cloud"
    purpose     = "Same Run"
    environment = "Test"
  }
  name             = "same-run"
  hash_key         = { name = "Id", type = "S" }
  stream_view_type = "NEW_AND_OLD_IMAGES"

  server_side_encryption = { kms_key_arn = aws_kms_key.table.arn }
  replicas = {
    us-west-2 = { kms_key_arn = aws_kms_key.replica.arn }
  }
}

output "metadata" {
  value = module.table.metadata
}
