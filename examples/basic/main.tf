# Copyright 2025 Automate the Cloud Inc.
# SPDX-License-Identifier: Apache-2.0

# An on-demand table with a partition key and a sort key, and the module's defaults for
# everything else: encrypted with the AWS managed key, point-in-time recovery on, and
# deletion protection on.

terraform {
  required_version = ">= 1.9"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.44"
    }
  }
}

provider "aws" {
  region = "us-east-1"
}

variable "name" {
  description = "Name of the table, unique in the account and Region"
  type        = string
  default     = "example-basic"
}

variable "deletion_protection_enabled" {
  description = "Whether AWS refuses to delete the table. Set it to false and apply before terraform destroy."
  type        = bool
  default     = true
}

module "dynamodb_table" {
  source = "../../"

  details = {
    scope       = "Example"
    purpose     = "Basic Table"
    environment = "Development"
  }

  name      = var.name
  hash_key  = { name = "UserId", type = "S" }
  range_key = { name = "GameTitle", type = "S" }

  deletion_protection_enabled = var.deletion_protection_enabled
}

output "dynamodb_table" {
  description = "Name and ARN of the table"
  value = {
    name = module.dynamodb_table.metadata.dynamodb_table.name
    arn  = module.dynamodb_table.metadata.dynamodb_table.arn
  }
}
