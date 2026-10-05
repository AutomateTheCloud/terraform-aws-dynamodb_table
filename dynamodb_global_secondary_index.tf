# Copyright 2025 Automate the Cloud Inc.
# SPDX-License-Identifier: Apache-2.0

# Global secondary indexes are separate resources, not blocks of the table, so that each can
# be autoscaled on its own. As with the table, `autoscaled` holds the indexes whose capacity
# Application Auto Scaling sets, and `this` the others. Keep their arguments identical.
resource "aws_dynamodb_global_secondary_index" "this" {
  for_each = local.global_secondary_indexes_fixed

  region = var.region

  table_name = local.table_name
  index_name = each.key

  key_schema {
    attribute_name = each.value.hash_key.name
    attribute_type = each.value.hash_key.type
    key_type       = "HASH"
  }

  dynamic "key_schema" {
    for_each = each.value.range_key == null ? [] : [each.value.range_key]
    content {
      attribute_name = key_schema.value.name
      attribute_type = key_schema.value.type
      key_type       = "RANGE"
    }
  }

  projection {
    projection_type    = each.value.projection_type
    non_key_attributes = each.value.projection_type == "INCLUDE" ? each.value.non_key_attributes : null
  }

  dynamic "provisioned_throughput" {
    for_each = local.provisioned ? [each.value] : []
    content {
      read_capacity_units  = provisioned_throughput.value.read_capacity
      write_capacity_units = provisioned_throughput.value.write_capacity
    }
  }

  timeouts {
    create = var.timeouts.create
    update = var.timeouts.update
    delete = var.timeouts.delete
  }
}

resource "aws_dynamodb_global_secondary_index" "autoscaled" {
  for_each = local.global_secondary_indexes_autoscaled

  region = var.region

  table_name = local.table_name
  index_name = each.key

  key_schema {
    attribute_name = each.value.hash_key.name
    attribute_type = each.value.hash_key.type
    key_type       = "HASH"
  }

  dynamic "key_schema" {
    for_each = each.value.range_key == null ? [] : [each.value.range_key]
    content {
      attribute_name = key_schema.value.name
      attribute_type = key_schema.value.type
      key_type       = "RANGE"
    }
  }

  projection {
    projection_type    = each.value.projection_type
    non_key_attributes = each.value.projection_type == "INCLUDE" ? each.value.non_key_attributes : null
  }

  # The index starts at its autoscaling minimum.
  provisioned_throughput {
    read_capacity_units  = each.value.autoscaling.read.min_capacity
    write_capacity_units = each.value.autoscaling.write.min_capacity
  }

  timeouts {
    create = var.timeouts.create
    update = var.timeouts.update
    delete = var.timeouts.delete
  }

  lifecycle {
    ignore_changes = [provisioned_throughput]
  }
}
