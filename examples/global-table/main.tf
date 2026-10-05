# Copyright 2025 Automate the Cloud Inc.
# SPDX-License-Identifier: Apache-2.0

# A global table: the table in us-east-1 and a replica in us-west-2. Each copy can be read
# and written, and DynamoDB keeps them in step.

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
  default     = "example-global-table"
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
    purpose     = "Global Table"
    environment = "Development"
  }

  name     = var.name
  hash_key = { name = "UserId", type = "S" }

  # Replicas need an on-demand table (the default) and a stream.
  stream_view_type = "NEW_AND_OLD_IMAGES"
  replicas = {
    us-west-2 = {}
  }

  deletion_protection_enabled = var.deletion_protection_enabled
}

output "dynamodb_table" {
  description = "ARN of the table and of each replica"
  value = {
    arn      = module.dynamodb_table.metadata.dynamodb_table.arn
    replicas = { for r in module.dynamodb_table.metadata.dynamodb_table.replica : r.region_name => r.arn }
  }
}
