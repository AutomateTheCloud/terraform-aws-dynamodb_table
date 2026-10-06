# Copyright 2026 Automate the Cloud Inc.
# SPDX-License-Identifier: Apache-2.0

locals {
  provisioned = var.billing_mode == "PROVISIONED"
  autoscaled  = var.autoscaling != null

  # The table's capacity. An autoscaled table starts at its minimum, and Application Auto
  # Scaling changes it from there.
  read_capacity  = local.provisioned ? (local.autoscaled ? var.autoscaling.read.min_capacity : var.read_capacity) : null
  write_capacity = local.provisioned ? (local.autoscaled ? var.autoscaling.write.min_capacity : var.write_capacity) : null

  # Attribute definitions for the table's own keys and its local secondary indexes, one per
  # name (the variables' validation makes sure each name has one type). Only key attributes
  # may be defined, or every plan shows a change. Global secondary indexes define their own.
  attributes = {
    for name, types in {
      for key in concat(
        [var.hash_key],
        var.range_key == null ? [] : [var.range_key],
        [for l in values(var.local_secondary_indexes) : l.range_key],
      ) : key.name => key.type...
    } : name => types[0]
  }

  table_tags = merge(local.tags, { "Name" = var.name })

  # The two table resources are alternatives: exactly one of them exists.
  table_name = one(concat(aws_dynamodb_table.this[*].name, aws_dynamodb_table.autoscaled[*].name))

  # Global secondary indexes, split the same way: with autoscaling or with fixed capacity.
  global_secondary_indexes_fixed      = { for k, v in var.global_secondary_indexes : k => v if v.autoscaling == null }
  global_secondary_indexes_autoscaled = { for k, v in var.global_secondary_indexes : k => v if v.autoscaling != null }

  # One Application Auto Scaling target and policy per autoscaled dimension, keyed like
  # "table/read" and "index/<index name>/write". Index names cannot contain "/", so the keys
  # cannot collide. The keys come from the inputs alone, so they are known at plan time.
  autoscaling_dimensions = merge(
    {
      for k, v in {
        "table/read" = {
          resource_id        = "table/${local.table_name}"
          scalable_dimension = "dynamodb:table:ReadCapacityUnits"
          metric             = "DynamoDBReadCapacityUtilization"
          settings           = try(var.autoscaling.read, null)
        }
        "table/write" = {
          resource_id        = "table/${local.table_name}"
          scalable_dimension = "dynamodb:table:WriteCapacityUnits"
          metric             = "DynamoDBWriteCapacityUtilization"
          settings           = try(var.autoscaling.write, null)
        }
      } : k => v if local.autoscaled
    },
    merge([for k, v in local.global_secondary_indexes_autoscaled : {
      "index/${k}/read" = {
        resource_id        = "table/${local.table_name}/index/${aws_dynamodb_global_secondary_index.autoscaled[k].index_name}"
        scalable_dimension = "dynamodb:index:ReadCapacityUnits"
        metric             = "DynamoDBReadCapacityUtilization"
        settings           = v.autoscaling.read
      }
      "index/${k}/write" = {
        resource_id        = "table/${local.table_name}/index/${aws_dynamodb_global_secondary_index.autoscaled[k].index_name}"
        scalable_dimension = "dynamodb:index:WriteCapacityUnits"
        metric             = "DynamoDBWriteCapacityUtilization"
        settings           = v.autoscaling.write
      }
    }]...),
  )
}
