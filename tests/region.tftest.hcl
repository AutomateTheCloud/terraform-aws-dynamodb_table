# Copyright 2026 Automate the Cloud Inc.
# SPDX-License-Identifier: Apache-2.0

# region reaches every resource and data source, and the module needs no providers block.
# Region abbreviations are computed, so a Region missing from the old hard-coded table
# no longer fails the plan.

mock_provider "aws" {
  mock_data "aws_region" {
    defaults = {
      region      = "mx-central-1"
      description = "Mexico (Central)"
    }
  }

  mock_data "aws_caller_identity" {
    defaults = {
      account_id = "123456789012"
    }
  }
}

variables {
  details = {
    scope       = "Automate the Cloud"
    purpose     = "Game Scores"
    environment = "Production"
  }
  name         = "game-scores"
  hash_key     = { name = "UserId", type = "S" }
  region       = "mx-central-1"
  billing_mode = "PROVISIONED"
  autoscaling = {
    read  = { min_capacity = 1, max_capacity = 5 }
    write = { min_capacity = 1, max_capacity = 5 }
  }
  global_secondary_indexes = {
    Fixed = {
      hash_key       = { name = "A", type = "S" }
      read_capacity  = 1
      write_capacity = 1
    }
    Scaled = {
      hash_key = { name = "B", type = "S" }
      autoscaling = {
        read  = { min_capacity = 1, max_capacity = 5 }
        write = { min_capacity = 1, max_capacity = 5 }
      }
    }
  }
}

run "region_everywhere" {
  command = plan

  assert {
    condition     = data.aws_region.this.region == "mx-central-1"
    error_message = "The Region data source must read var.region."
  }

  assert {
    condition     = aws_dynamodb_table.autoscaled[0].region == "mx-central-1"
    error_message = "region must reach the table."
  }

  assert {
    condition     = alltrue([for i in values(merge(aws_dynamodb_global_secondary_index.this, aws_dynamodb_global_secondary_index.autoscaled)) : i.region == "mx-central-1"])
    error_message = "region must reach every index."
  }

  assert {
    condition     = alltrue(concat([for t in values(aws_appautoscaling_target.this) : t.region == "mx-central-1"], [for p in values(aws_appautoscaling_policy.this) : p.region == "mx-central-1"]))
    error_message = "region must reach every autoscaling target and policy."
  }
}

run "region_not_in_old_table" {
  command = apply

  assert {
    condition     = output.metadata.aws.region.abbr == "mxc1"
    error_message = "mx-central-1 must abbreviate to mxc1."
  }
}

run "fixed_table_region" {
  command = plan

  variables {
    billing_mode             = "PAY_PER_REQUEST"
    autoscaling              = null
    global_secondary_indexes = {}
  }

  assert {
    condition     = aws_dynamodb_table.this[0].region == "mx-central-1"
    error_message = "region must reach the fixed-capacity table too."
  }
}
