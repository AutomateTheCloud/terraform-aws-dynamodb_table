# Copyright 2025 Automate the Cloud Inc.
# SPDX-License-Identifier: Apache-2.0

# Each validation rejects a value that AWS would reject, or that would not do what it
# says, at plan time with a clear message.

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
    purpose     = "Validation"
    environment = "Test"
  }
  name     = "validation"
  hash_key = { name = "Id", type = "S" }
}

run "details_scope_empty" {
  command = plan

  variables {
    details = { scope = " ", purpose = "P", environment = "E" }
  }

  expect_failures = [var.details]
}

run "details_purpose_empty" {
  command = plan

  variables {
    details = { scope = "S", purpose = "", environment = "E" }
  }

  expect_failures = [var.details]
}

run "details_environment_empty" {
  command = plan

  variables {
    details = { scope = "S", purpose = "P", environment = "" }
  }

  expect_failures = [var.details]
}

# Regression: the old module accepted an empty name, its default.
run "name_empty" {
  command = plan

  variables {
    name = ""
  }

  expect_failures = [var.name]
}

run "name_bad_characters" {
  command = plan

  variables {
    name = "my table"
  }

  expect_failures = [var.name]
}

run "hash_key_bad_type" {
  command = plan

  variables {
    hash_key = { name = "Id", type = "STRING" }
  }

  expect_failures = [var.hash_key]
}

# Regression: the old module accepted a table with no hash key.
run "hash_key_no_name" {
  command = plan

  variables {
    hash_key = { name = "", type = "S" }
  }

  expect_failures = [var.hash_key]
}

run "range_key_bad_type" {
  command = plan

  variables {
    range_key = { name = "Sort", type = "BOOL" }
  }

  expect_failures = [var.range_key]
}

run "range_key_same_as_hash" {
  command = plan

  variables {
    range_key = { name = "Id", type = "S" }
  }

  expect_failures = [var.range_key]
}

run "billing_mode_invalid" {
  command = plan

  variables {
    billing_mode = "ON_DEMAND"
  }

  expect_failures = [var.billing_mode]
}

run "provisioned_without_capacity" {
  command = plan

  variables {
    billing_mode = "PROVISIONED"
  }

  expect_failures = [var.read_capacity, var.write_capacity]
}

run "on_demand_with_capacity" {
  command = plan

  variables {
    read_capacity  = 5
    write_capacity = 5
  }

  expect_failures = [var.read_capacity, var.write_capacity]
}

run "autoscaling_with_capacity" {
  command = plan

  variables {
    billing_mode   = "PROVISIONED"
    read_capacity  = 5
    write_capacity = 5
    autoscaling    = { read = { min_capacity = 1, max_capacity = 5 }, write = { min_capacity = 1, max_capacity = 5 } }
  }

  expect_failures = [var.read_capacity, var.write_capacity]
}

# Regression: the old module planned autoscaling for an on-demand table, and failed with "min_capacity is required".
run "autoscaling_on_demand" {
  command = plan

  variables {
    autoscaling = { read = { min_capacity = 1, max_capacity = 5 }, write = { min_capacity = 1, max_capacity = 5 } }
  }

  expect_failures = [var.autoscaling]
}

run "autoscaling_max_below_min" {
  command = plan

  variables {
    billing_mode = "PROVISIONED"
    autoscaling  = { read = { min_capacity = 10, max_capacity = 5 }, write = { min_capacity = 1, max_capacity = 5 } }
  }

  expect_failures = [var.autoscaling]
}

run "autoscaling_target_too_high" {
  command = plan

  variables {
    billing_mode = "PROVISIONED"
    autoscaling  = { read = { min_capacity = 1, max_capacity = 5 }, write = { min_capacity = 1, max_capacity = 5, target_value = 95 } }
  }

  expect_failures = [var.autoscaling]
}

run "autoscaling_negative_cooldown" {
  command = plan

  variables {
    billing_mode = "PROVISIONED"
    autoscaling  = { read = { min_capacity = 1, max_capacity = 5, scale_in_cooldown = -1 }, write = { min_capacity = 1, max_capacity = 5 } }
  }

  expect_failures = [var.autoscaling]
}

run "gsi_bad_name" {
  command = plan

  variables {
    global_secondary_indexes = { "ab" = { hash_key = { name = "A", type = "S" } } }
  }

  expect_failures = [var.global_secondary_indexes]
}

run "gsi_bad_key_type" {
  command = plan

  variables {
    global_secondary_indexes = { Index1 = { hash_key = { name = "A", type = "X" } } }
  }

  expect_failures = [var.global_secondary_indexes]
}

run "gsi_same_hash_and_range" {
  command = plan

  variables {
    global_secondary_indexes = { Index1 = { hash_key = { name = "A", type = "S" }, range_key = { name = "A", type = "S" } } }
  }

  expect_failures = [var.global_secondary_indexes]
}

run "gsi_include_without_attributes" {
  command = plan

  variables {
    global_secondary_indexes = { Index1 = { hash_key = { name = "A", type = "S" }, projection_type = "INCLUDE" } }
  }

  expect_failures = [var.global_secondary_indexes]
}

run "gsi_attributes_without_include" {
  command = plan

  variables {
    global_secondary_indexes = { Index1 = { hash_key = { name = "A", type = "S" }, non_key_attributes = ["B"] } }
  }

  expect_failures = [var.global_secondary_indexes]
}

run "gsi_bad_projection" {
  command = plan

  variables {
    global_secondary_indexes = { Index1 = { hash_key = { name = "A", type = "S" }, projection_type = "SOME" } }
  }

  expect_failures = [var.global_secondary_indexes]
}

run "gsi_on_demand_with_capacity" {
  command = plan

  variables {
    global_secondary_indexes = { Index1 = { hash_key = { name = "A", type = "S" }, read_capacity = 1, write_capacity = 1 } }
  }

  expect_failures = [var.global_secondary_indexes]
}

run "gsi_on_demand_with_autoscaling" {
  command = plan

  variables {
    global_secondary_indexes = { Index1 = { hash_key = { name = "A", type = "S" }, autoscaling = { read = { min_capacity = 1, max_capacity = 5 }, write = { min_capacity = 1, max_capacity = 5 } } } }
  }

  expect_failures = [var.global_secondary_indexes]
}

run "gsi_provisioned_without_capacity" {
  command = plan

  variables {
    billing_mode             = "PROVISIONED"
    read_capacity            = 1
    write_capacity           = 1
    global_secondary_indexes = { Index1 = { hash_key = { name = "A", type = "S" }, read_capacity = 1 } }
  }

  expect_failures = [var.global_secondary_indexes]
}

run "gsi_capacity_and_autoscaling" {
  command = plan

  variables {
    billing_mode             = "PROVISIONED"
    read_capacity            = 1
    write_capacity           = 1
    global_secondary_indexes = { Index1 = { hash_key = { name = "A", type = "S" }, read_capacity = 1, write_capacity = 1, autoscaling = { read = { min_capacity = 1, max_capacity = 5 }, write = { min_capacity = 1, max_capacity = 5 } } } }
  }

  expect_failures = [var.global_secondary_indexes]
}

run "gsi_autoscaling_out_of_range" {
  command = plan

  variables {
    billing_mode             = "PROVISIONED"
    read_capacity            = 1
    write_capacity           = 1
    global_secondary_indexes = { Index1 = { hash_key = { name = "A", type = "S" }, autoscaling = { read = { min_capacity = 0, max_capacity = 5 }, write = { min_capacity = 1, max_capacity = 5 } } } }
  }

  expect_failures = [var.global_secondary_indexes]
}

run "gsi_same_name_as_lsi" {
  command = plan

  variables {
    range_key                = { name = "Sort", type = "S" }
    local_secondary_indexes  = { Index1 = { range_key = { name = "B", type = "S" } } }
    global_secondary_indexes = { Index1 = { hash_key = { name = "A", type = "S" } } }
  }

  expect_failures = [var.global_secondary_indexes]
}

# The same attribute as a string key in the table and a number key in an index.
run "attribute_with_two_types" {
  command = plan

  variables {
    global_secondary_indexes = { Index1 = { hash_key = { name = "Id", type = "N" } } }
  }

  expect_failures = [var.global_secondary_indexes]
}

run "lsi_without_range_key" {
  command = plan

  variables {
    local_secondary_indexes = { Index1 = { range_key = { name = "B", type = "S" } } }
  }

  expect_failures = [var.local_secondary_indexes]
}

run "lsi_bad_name" {
  command = plan

  variables {
    range_key               = { name = "Sort", type = "S" }
    local_secondary_indexes = { "x" = { range_key = { name = "B", type = "S" } } }
  }

  expect_failures = [var.local_secondary_indexes]
}

run "lsi_more_than_five" {
  command = plan

  variables {
    range_key               = { name = "Sort", type = "S" }
    local_secondary_indexes = { for i in range(6) : "Index${i}" => { range_key = { name = "B${i}", type = "S" } } }
  }

  expect_failures = [var.local_secondary_indexes]
}

run "lsi_key_is_hash_key" {
  command = plan

  variables {
    range_key               = { name = "Sort", type = "S" }
    local_secondary_indexes = { Index1 = { range_key = { name = "Id", type = "S" } } }
  }

  expect_failures = [var.local_secondary_indexes]
}

run "lsi_include_without_attributes" {
  command = plan

  variables {
    range_key               = { name = "Sort", type = "S" }
    local_secondary_indexes = { Index1 = { range_key = { name = "B", type = "S" }, projection_type = "INCLUDE" } }
  }

  expect_failures = [var.local_secondary_indexes]
}

run "recovery_period_too_long" {
  command = plan

  variables {
    point_in_time_recovery = { recovery_period_in_days = 36 }
  }

  expect_failures = [var.point_in_time_recovery]
}

run "recovery_period_fraction" {
  command = plan

  variables {
    point_in_time_recovery = { recovery_period_in_days = 1.5 }
  }

  expect_failures = [var.point_in_time_recovery]
}

run "recovery_period_with_recovery_off" {
  command = plan

  variables {
    point_in_time_recovery = { enabled = false, recovery_period_in_days = 7 }
  }

  expect_failures = [var.point_in_time_recovery]
}

run "kms_key_with_aws_owned_key" {
  command = plan

  variables {
    server_side_encryption = { enabled = false, kms_key_arn = "arn:aws:kms:us-east-1:123456789012:key/1111aaaa-11aa-11aa-11aa-1111aaaa1111" }
  }

  expect_failures = [var.server_side_encryption]
}

run "kms_key_not_an_arn" {
  command = plan

  variables {
    server_side_encryption = { kms_key_arn = "alias/my-key" }
  }

  expect_failures = [var.server_side_encryption]
}

# Regression: the old module also accepted a view type with the stream off, which provider 6.67 warns will become an error.
run "stream_view_type_invalid" {
  command = plan

  variables {
    stream_view_type = "ALL"
  }

  expect_failures = [var.stream_view_type]
}

run "table_class_invalid" {
  command = plan

  variables {
    table_class = "INFREQUENT_ACCESS"
  }

  expect_failures = [var.table_class]
}

run "ttl_empty" {
  command = plan

  variables {
    ttl = { attribute_name = "" }
  }

  expect_failures = [var.ttl]
}

run "replica_not_a_region" {
  command = plan

  variables {
    stream_view_type = "NEW_AND_OLD_IMAGES"
    replicas         = { "west" = {} }
  }

  expect_failures = [var.replicas]
}

run "replica_without_stream" {
  command = plan

  variables {
    replicas = { us-west-2 = {} }
  }

  expect_failures = [var.replicas]
}

run "replica_provisioned" {
  command = plan

  variables {
    billing_mode     = "PROVISIONED"
    read_capacity    = 1
    write_capacity   = 1
    stream_view_type = "NEW_AND_OLD_IMAGES"
    replicas         = { us-west-2 = {} }
  }

  expect_failures = [var.replicas]
}

# With a customer managed key on the table, a replica without its own key would fail at apply.
run "replica_without_key" {
  command = plan

  variables {
    stream_view_type       = "NEW_AND_OLD_IMAGES"
    server_side_encryption = { kms_key_arn = "arn:aws:kms:us-east-1:123456789012:key/1111aaaa-11aa-11aa-11aa-1111aaaa1111" }
    replicas               = { us-west-2 = {} }
  }

  expect_failures = [var.replicas]
}

run "replica_key_without_table_key" {
  command = plan

  variables {
    stream_view_type = "NEW_AND_OLD_IMAGES"
    replicas         = { us-west-2 = { kms_key_arn = "arn:aws:kms:us-west-2:123456789012:key/2222bbbb-22bb-22bb-22bb-2222bbbb2222" } }
  }

  expect_failures = [var.replicas]
}
