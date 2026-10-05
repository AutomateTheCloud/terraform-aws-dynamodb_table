# Copyright 2025 Automate the Cloud Inc.
# SPDX-License-Identifier: Apache-2.0

# An autoscaled table and index are the resources that ignore capacity changes, start at
# their minimum, and get one target and one target tracking policy per dimension.

mock_provider "aws" {
  mock_data "aws_region" {
    defaults = {
      region      = "us-east-1"
      description = "US East (N. Virginia)"
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
  billing_mode = "PROVISIONED"
  autoscaling = {
    read  = { min_capacity = 5, max_capacity = 50, target_value = 45, scale_in_cooldown = 11, scale_out_cooldown = 12 }
    write = { min_capacity = 2, max_capacity = 20, target_value = 80, scale_in_cooldown = 21, scale_out_cooldown = 22 }
  }
  global_secondary_indexes = {
    GameTitleIndex = {
      hash_key = { name = "GameTitle", type = "S" }
      autoscaling = {
        read  = { min_capacity = 3, max_capacity = 30 }
        write = { min_capacity = 1, max_capacity = 10, target_value = 60 }
      }
    }
    LossesIndex = {
      hash_key       = { name = "Losses", type = "N" }
      read_capacity  = 4
      write_capacity = 4
    }
  }
}

run "autoscaled_resources" {
  command = plan

  assert {
    condition     = length(aws_dynamodb_table.this) == 0 && length(aws_dynamodb_table.autoscaled) == 1
    error_message = "With autoscaling, the table must be the autoscaled resource."
  }

  assert {
    condition     = aws_dynamodb_table.autoscaled[0].read_capacity == 5 && aws_dynamodb_table.autoscaled[0].write_capacity == 2
    error_message = "The table must start at the autoscaling minimum."
  }

  assert {
    condition     = keys(aws_dynamodb_global_secondary_index.autoscaled) == ["GameTitleIndex"] && keys(aws_dynamodb_global_secondary_index.this) == ["LossesIndex"]
    error_message = "Only the index with autoscaling must be the autoscaled resource."
  }

  assert {
    condition     = one(aws_dynamodb_global_secondary_index.autoscaled["GameTitleIndex"].provisioned_throughput).read_capacity_units == 3 && one(aws_dynamodb_global_secondary_index.autoscaled["GameTitleIndex"].provisioned_throughput).write_capacity_units == 1
    error_message = "The autoscaled index must start at its minimum."
  }

  assert {
    condition     = keys(aws_appautoscaling_target.this) == ["index/GameTitleIndex/read", "index/GameTitleIndex/write", "table/read", "table/write"]
    error_message = "There must be one target per autoscaled dimension, and none for the fixed index."
  }

  assert {
    condition = (
      aws_appautoscaling_target.this["table/read"].resource_id == "table/game-scores" &&
      aws_appautoscaling_target.this["table/read"].scalable_dimension == "dynamodb:table:ReadCapacityUnits" &&
      aws_appautoscaling_target.this["table/write"].scalable_dimension == "dynamodb:table:WriteCapacityUnits" &&
      aws_appautoscaling_target.this["index/GameTitleIndex/read"].resource_id == "table/game-scores/index/GameTitleIndex" &&
      aws_appautoscaling_target.this["index/GameTitleIndex/write"].scalable_dimension == "dynamodb:index:WriteCapacityUnits"
    )
    error_message = "Each target must point at its table or index and dimension."
  }

  assert {
    condition = (
      aws_appautoscaling_target.this["table/read"].min_capacity == 5 && aws_appautoscaling_target.this["table/read"].max_capacity == 50 &&
      aws_appautoscaling_target.this["table/write"].min_capacity == 2 && aws_appautoscaling_target.this["table/write"].max_capacity == 20 &&
      aws_appautoscaling_target.this["index/GameTitleIndex/read"].max_capacity == 30
    )
    error_message = "Each target must get its own minimum and maximum."
  }

  assert {
    condition     = aws_appautoscaling_policy.this["table/write"].name == "DynamoDBWriteCapacityUtilization:table/game-scores" && one(one(aws_appautoscaling_policy.this["table/write"].target_tracking_scaling_policy_configuration).predefined_metric_specification).predefined_metric_type == "DynamoDBWriteCapacityUtilization"
    error_message = "The write policy must track write capacity utilization."
  }

  assert {
    condition     = one(aws_appautoscaling_policy.this["table/read"].target_tracking_scaling_policy_configuration).target_value == 45
    error_message = "The read policy must use the read settings."
  }

  # Regression: the old module's write policy took its target and cooldowns from the read
  # settings, so a write target of 80 was planned as 45.
  assert {
    condition = (
      one(aws_appautoscaling_policy.this["table/write"].target_tracking_scaling_policy_configuration).target_value == 80 &&
      one(aws_appautoscaling_policy.this["table/write"].target_tracking_scaling_policy_configuration).scale_in_cooldown == 21 &&
      one(aws_appautoscaling_policy.this["table/write"].target_tracking_scaling_policy_configuration).scale_out_cooldown == 22
    )
    error_message = "The write policy must use the write settings, not the read settings."
  }

  assert {
    condition = (
      one(aws_appautoscaling_policy.this["index/GameTitleIndex/read"].target_tracking_scaling_policy_configuration).target_value == 70 &&
      one(aws_appautoscaling_policy.this["index/GameTitleIndex/read"].target_tracking_scaling_policy_configuration).scale_in_cooldown == 0 &&
      one(aws_appautoscaling_policy.this["index/GameTitleIndex/write"].target_tracking_scaling_policy_configuration).target_value == 60
    )
    error_message = "Index policies must use their own settings, with 70 and 0 as defaults."
  }
}

run "autoscaled_metadata" {
  command = apply

  assert {
    condition     = output.metadata.dynamodb_table.read_capacity == null && output.metadata.dynamodb_table.write_capacity == null
    error_message = "Capacity set by autoscaling must be null in metadata, so the output does not change on every scale."
  }

  assert {
    condition     = output.metadata.dynamodb_global_secondary_index["GameTitleIndex"].provisioned_throughput == null && length(output.metadata.dynamodb_global_secondary_index["LossesIndex"].provisioned_throughput) == 1
    error_message = "Only the autoscaled index's throughput must be null in metadata."
  }

  assert {
    condition     = length(output.metadata.appautoscaling_target) == 4 && length(output.metadata.appautoscaling_policy) == 4
    error_message = "metadata must list every target and policy."
  }
}
