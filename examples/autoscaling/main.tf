# Copyright 2026 Automate the Cloud Inc.
# SPDX-License-Identifier: Apache-2.0

# A table with provisioned capacity that Application Auto Scaling adjusts to the load,
# and a global secondary index that scales the same way.

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
  default     = "example-autoscaling"
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
    purpose     = "Autoscaled Table"
    environment = "Development"
  }

  name         = var.name
  hash_key     = { name = "UserId", type = "S" }
  billing_mode = "PROVISIONED"

  # The table starts at the minimum. Application Auto Scaling keeps about 70 percent of
  # the capacity in use, between the minimum and the maximum.
  autoscaling = {
    read  = { min_capacity = 2, max_capacity = 20 }
    write = { min_capacity = 1, max_capacity = 10 }
  }

  global_secondary_indexes = {
    GameTitleIndex = {
      hash_key = { name = "GameTitle", type = "S" }
      autoscaling = {
        read  = { min_capacity = 1, max_capacity = 10, target_value = 50 }
        write = { min_capacity = 1, max_capacity = 5 }
      }
    }
  }

  deletion_protection_enabled = var.deletion_protection_enabled
}

output "autoscaling" {
  description = "Minimum and maximum capacity of each autoscaled table and index dimension"
  value = {
    for k, v in module.dynamodb_table.metadata.appautoscaling_target : k => {
      min_capacity = v.min_capacity
      max_capacity = v.max_capacity
    }
  }
}
