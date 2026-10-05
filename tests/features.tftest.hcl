# Copyright 2025 Automate the Cloud Inc.
# SPDX-License-Identifier: Apache-2.0

# Keys, indexes, streams, TTL, replicas and encryption reach the resources as configured.

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
  name      = "game-scores"
  hash_key  = { name = "UserId", type = "S" }
  range_key = { name = "GameTitle", type = "S" }
}

run "keys_and_indexes" {
  command = plan

  variables {
    local_secondary_indexes = {
      TopScoreIndex = {
        range_key          = { name = "TopScore", type = "N" }
        projection_type    = "INCLUDE"
        non_key_attributes = ["Wins"]
      }
    }
    global_secondary_indexes = {
      GameTitleIndex = {
        hash_key  = { name = "GameTitle", type = "S" }
        range_key = { name = "TopScore", type = "N" }
      }
      LossesIndex = {
        hash_key        = { name = "Losses", type = "N" }
        projection_type = "KEYS_ONLY"
      }
    }
  }

  # Only the table's keys and the local index's key are table attributes; the global
  # indexes define their own (an unused attribute makes every plan show a change).
  assert {
    condition     = toset([for a in aws_dynamodb_table.this[0].attribute : "${a.name}|${a.type}"]) == toset(["UserId|S", "GameTitle|S", "TopScore|N"])
    error_message = "The table's attributes must be exactly its keys and the local index's sort key."
  }

  assert {
    condition     = aws_dynamodb_table.this[0].range_key == "GameTitle"
    error_message = "range_key must reach the table."
  }

  assert {
    condition     = toset([for l in aws_dynamodb_table.this[0].local_secondary_index : "${l.name}|${l.range_key}|${l.projection_type}|${join(",", l.non_key_attributes)}"]) == toset(["TopScoreIndex|TopScore|INCLUDE|Wins"])
    error_message = "The local secondary index must reach the table."
  }

  # Regression: the old module used the global index block's hash_key and range_key,
  # which provider 6.67 deprecates. The indexes now use key_schema.
  assert {
    condition     = [for k in aws_dynamodb_global_secondary_index.this["GameTitleIndex"].key_schema : "${k.attribute_name}|${k.attribute_type}|${k.key_type}"] == ["GameTitle|S|HASH", "TopScore|N|RANGE"]
    error_message = "GameTitleIndex must have a HASH and a RANGE key, in that order."
  }

  assert {
    condition     = [for k in aws_dynamodb_global_secondary_index.this["LossesIndex"].key_schema : "${k.attribute_name}|${k.key_type}"] == ["Losses|HASH"]
    error_message = "LossesIndex must have only a HASH key."
  }

  assert {
    condition     = one(aws_dynamodb_global_secondary_index.this["GameTitleIndex"].projection).projection_type == "ALL" && one(aws_dynamodb_global_secondary_index.this["LossesIndex"].projection).projection_type == "KEYS_ONLY"
    error_message = "The projections must reach the indexes, ALL by default."
  }

  assert {
    condition     = length(aws_dynamodb_global_secondary_index.this["GameTitleIndex"].provisioned_throughput) == 0
    error_message = "An index of an on-demand table must have no provisioned throughput."
  }

  assert {
    condition     = aws_dynamodb_global_secondary_index.this["GameTitleIndex"].table_name == "game-scores" && aws_dynamodb_global_secondary_index.this["GameTitleIndex"].index_name == "GameTitleIndex"
    error_message = "The index must belong to the table, named by its key."
  }
}

run "provisioned_fixed_capacity" {
  command = plan

  variables {
    billing_mode   = "PROVISIONED"
    read_capacity  = 5
    write_capacity = 2
    global_secondary_indexes = {
      GameTitleIndex = {
        hash_key       = { name = "GameTitle", type = "S" }
        read_capacity  = 3
        write_capacity = 1
      }
    }
  }

  assert {
    condition     = aws_dynamodb_table.this[0].read_capacity == 5 && aws_dynamodb_table.this[0].write_capacity == 2
    error_message = "Fixed capacity must reach the table."
  }

  assert {
    condition     = one(aws_dynamodb_global_secondary_index.this["GameTitleIndex"].provisioned_throughput).read_capacity_units == 3 && one(aws_dynamodb_global_secondary_index.this["GameTitleIndex"].provisioned_throughput).write_capacity_units == 1
    error_message = "Fixed capacity must reach the index."
  }

  assert {
    condition     = length(aws_appautoscaling_target.this) == 0
    error_message = "Fixed capacity must not be autoscaled."
  }
}

run "stream_ttl_class_recovery" {
  command = plan

  variables {
    stream_view_type            = "NEW_IMAGE"
    ttl                         = { attribute_name = "ExpiresAt" }
    table_class                 = "STANDARD_INFREQUENT_ACCESS"
    point_in_time_recovery      = { recovery_period_in_days = 7 }
    deletion_protection_enabled = false
  }

  assert {
    condition     = aws_dynamodb_table.this[0].stream_enabled && aws_dynamodb_table.this[0].stream_view_type == "NEW_IMAGE"
    error_message = "stream_view_type must turn on the stream."
  }

  assert {
    condition     = one(aws_dynamodb_table.this[0].ttl).enabled && one(aws_dynamodb_table.this[0].ttl).attribute_name == "ExpiresAt"
    error_message = "ttl must turn on TTL for that attribute."
  }

  assert {
    condition     = aws_dynamodb_table.this[0].table_class == "STANDARD_INFREQUENT_ACCESS"
    error_message = "table_class must reach the table."
  }

  assert {
    condition     = one(aws_dynamodb_table.this[0].point_in_time_recovery).enabled && one(aws_dynamodb_table.this[0].point_in_time_recovery).recovery_period_in_days == 7
    error_message = "The recovery period must reach the table, with recovery still on."
  }

  assert {
    condition     = aws_dynamodb_table.this[0].deletion_protection_enabled == false
    error_message = "Deletion protection must be possible to turn off."
  }
}

# Turning TTL off keeps the attribute's name: AWS rejects a request to turn it off without
# one, which is what setting the old ttl_attribute_name input to null sent.
run "ttl_off_keeps_attribute_name" {
  command = plan

  variables {
    ttl = { attribute_name = "ExpiresAt", enabled = false }
  }

  assert {
    condition     = one(aws_dynamodb_table.this[0].ttl).enabled == false && one(aws_dynamodb_table.this[0].ttl).attribute_name == "ExpiresAt"
    error_message = "ttl.enabled = false must keep the attribute name."
  }
}

run "aws_owned_key" {
  command = plan

  variables {
    server_side_encryption = { enabled = false }
  }

  assert {
    condition     = one(aws_dynamodb_table.this[0].server_side_encryption).enabled == false
    error_message = "enabled = false must select the AWS owned key."
  }
}

# Regression: replica_regions was a list of names, so a table encrypted with a customer
# managed key could not give its replicas a key in their own Region.
run "replicas_with_customer_managed_keys" {
  command = plan

  variables {
    stream_view_type       = "NEW_AND_OLD_IMAGES"
    server_side_encryption = { kms_key_arn = "arn:aws:kms:us-east-1:123456789012:key/1111aaaa-11aa-11aa-11aa-1111aaaa1111" }
    replicas = {
      us-west-2 = { kms_key_arn = "arn:aws:kms:us-west-2:123456789012:key/2222bbbb-22bb-22bb-22bb-2222bbbb2222" }
      eu-west-1 = {
        kms_key_arn                 = "arn:aws:kms:eu-west-1:123456789012:key/3333cccc-33cc-33cc-33cc-3333cccc3333"
        point_in_time_recovery      = false
        deletion_protection_enabled = false
        propagate_tags              = false
      }
    }
  }

  assert {
    condition     = one(aws_dynamodb_table.this[0].server_side_encryption).kms_key_arn == "arn:aws:kms:us-east-1:123456789012:key/1111aaaa-11aa-11aa-11aa-1111aaaa1111"
    error_message = "The table's key must reach the table."
  }

  assert {
    condition = toset([for r in aws_dynamodb_table.this[0].replica : "${r.region_name}|${r.kms_key_arn}|${r.point_in_time_recovery}|${r.deletion_protection_enabled}|${r.propagate_tags}"]) == toset([
      "us-west-2|arn:aws:kms:us-west-2:123456789012:key/2222bbbb-22bb-22bb-22bb-2222bbbb2222|true|true|true",
      "eu-west-1|arn:aws:kms:eu-west-1:123456789012:key/3333cccc-33cc-33cc-33cc-3333cccc3333|false|false|false",
    ])
    error_message = "Each replica must get its own key, and the table's settings unless it sets its own."
  }
}

run "replica_in_own_region" {
  command = plan

  variables {
    stream_view_type = "NEW_AND_OLD_IMAGES"
    replicas         = { us-east-1 = {} }
  }

  expect_failures = [aws_dynamodb_table.this]
}
