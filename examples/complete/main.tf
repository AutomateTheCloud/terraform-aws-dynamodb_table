# Copyright 2026 Automate the Cloud Inc.
# SPDX-License-Identifier: Apache-2.0

# A table of game scores with the options most applications use: a local secondary index
# and two global secondary indexes, a stream of changes, time to live, a customer managed
# key, and a shorter point-in-time recovery period.

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
  default     = "example-complete"
}

variable "deletion_protection_enabled" {
  description = "Whether AWS refuses to delete the table. Set it to false and apply before terraform destroy."
  type        = bool
  default     = true
}

# A customer managed key for the table. AWS charges a monthly fee for each key, and
# deletes it 7 days after terraform destroy.
resource "aws_kms_key" "table" {
  description             = "Encrypts the ${var.name} DynamoDB table"
  enable_key_rotation     = true
  deletion_window_in_days = 7
}

module "dynamodb_table" {
  source = "../../"

  details = {
    scope           = "Example"
    purpose         = "Game Scores"
    environment     = "Development"
    additional_tags = { CostCenter = "1234" }
  }

  name      = var.name
  hash_key  = { name = "UserId", type = "S" }
  range_key = { name = "GameTitle", type = "S" }

  # Each player's games, sorted by score. Created with the table only.
  local_secondary_indexes = {
    TopScoreIndex = {
      range_key = { name = "TopScore", type = "N" }
    }
  }

  # The best players of each game, and every game a player has lost, without reading the
  # whole table.
  global_secondary_indexes = {
    GameTitleIndex = {
      hash_key           = { name = "GameTitle", type = "S" }
      range_key          = { name = "TopScore", type = "N" }
      projection_type    = "INCLUDE"
      non_key_attributes = ["Wins", "Losses"]
    }
    LossesIndex = {
      hash_key        = { name = "Losses", type = "N" }
      projection_type = "KEYS_ONLY"
    }
  }

  stream_view_type       = "NEW_AND_OLD_IMAGES"
  ttl                    = { attribute_name = "ExpiresAt" }
  point_in_time_recovery = { recovery_period_in_days = 14 }
  server_side_encryption = { kms_key_arn = aws_kms_key.table.arn }

  deletion_protection_enabled = var.deletion_protection_enabled
}

output "dynamodb_table" {
  description = "Name, ARN and stream ARN of the table, and the ARNs of its global secondary indexes"
  value = {
    name       = module.dynamodb_table.metadata.dynamodb_table.name
    arn        = module.dynamodb_table.metadata.dynamodb_table.arn
    stream_arn = module.dynamodb_table.metadata.dynamodb_table.stream_arn
    indexes    = { for k, v in module.dynamodb_table.metadata.dynamodb_global_secondary_index : k => v.arn }
  }
}
