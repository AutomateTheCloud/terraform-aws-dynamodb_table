# Copyright 2025 Automate the Cloud Inc.
# SPDX-License-Identifier: Apache-2.0

# A table created with only the required inputs: on demand, encrypted with the AWS managed
# key, point-in-time recovery on, deletion protection on, and nothing else switched on.

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
    purpose     = "Course Progress"
    environment = "Production"
  }
  name     = "course-progress"
  hash_key = { name = "UserId", type = "S" }
}

run "secure_defaults" {
  command = plan

  assert {
    condition     = length(aws_dynamodb_table.this) == 1 && length(aws_dynamodb_table.autoscaled) == 0
    error_message = "Without autoscaling, the table must be the fixed-capacity resource."
  }

  assert {
    condition     = aws_dynamodb_table.this[0].billing_mode == "PAY_PER_REQUEST" && local.read_capacity == null && local.write_capacity == null
    error_message = "The default must be an on-demand table with no capacity set."
  }

  assert {
    condition     = one(aws_dynamodb_table.this[0].server_side_encryption).enabled == true && var.server_side_encryption.kms_key_arn == null
    error_message = "The default must encrypt with the AWS managed key aws/dynamodb."
  }

  assert {
    condition     = one(aws_dynamodb_table.this[0].point_in_time_recovery).enabled == true && var.point_in_time_recovery.recovery_period_in_days == null
    error_message = "Point-in-time recovery must be on by default, with AWS's recovery period."
  }

  assert {
    condition     = aws_dynamodb_table.this[0].deletion_protection_enabled == true
    error_message = "Deletion protection must be on by default."
  }

  assert {
    condition     = aws_dynamodb_table.this[0].stream_enabled == false && var.stream_view_type == null
    error_message = "Streams must be off by default."
  }

  assert {
    condition     = one(aws_dynamodb_table.this[0].ttl).enabled == false && one(aws_dynamodb_table.this[0].ttl).attribute_name == null
    error_message = "TTL must be off by default."
  }

  assert {
    condition     = aws_dynamodb_table.this[0].table_class == "STANDARD"
    error_message = "The default table class must be STANDARD."
  }

  assert {
    condition     = toset([for a in aws_dynamodb_table.this[0].attribute : "${a.name}|${a.type}"]) == toset(["UserId|S"])
    error_message = "Only the hash key must be defined as an attribute."
  }

  assert {
    condition     = aws_dynamodb_table.this[0].hash_key == "UserId" && aws_dynamodb_table.this[0].range_key == null
    error_message = "The hash key must be UserId, with no range key."
  }

  assert {
    condition     = length(aws_dynamodb_table.this[0].replica) == 0 && length(aws_dynamodb_table.this[0].local_secondary_index) == 0
    error_message = "No replicas or local secondary indexes by default."
  }

  assert {
    condition     = length(aws_dynamodb_global_secondary_index.this) == 0 && length(aws_dynamodb_global_secondary_index.autoscaled) == 0
    error_message = "No global secondary indexes by default."
  }

  assert {
    condition     = length(aws_appautoscaling_target.this) == 0 && length(aws_appautoscaling_policy.this) == 0
    error_message = "No autoscaling by default."
  }

  assert {
    condition = aws_dynamodb_table.this[0].tags == tomap({
      Scope       = "Automate the Cloud"
      Purpose     = "Course Progress"
      Environment = "Production"
      Name        = "course-progress"
    })
    error_message = "The table must be tagged with the details and its name."
  }
}

run "metadata" {
  command = apply

  assert {
    condition     = output.metadata.dynamodb_table.name == "course-progress" && output.metadata.dynamodb_table.billing_mode == "PAY_PER_REQUEST"
    error_message = "metadata.dynamodb_table must describe the table."
  }

  assert {
    condition     = output.metadata.dynamodb_global_secondary_index == null && output.metadata.appautoscaling_target == null && output.metadata.appautoscaling_policy == null
    error_message = "Entries for resources that are not created must be null."
  }

  assert {
    condition     = output.metadata.aws.account.id == "123456789012" && output.metadata.aws.region.name == "us-east-1" && output.metadata.aws.region.abbr == "use1"
    error_message = "metadata.aws must give the account and Region."
  }

  assert {
    condition     = output.metadata.details.scope.abbr == "automate_the_cloud" && output.metadata.details.purpose.machine == "courseprogress"
    error_message = "metadata.details must give the abbreviations."
  }
}
