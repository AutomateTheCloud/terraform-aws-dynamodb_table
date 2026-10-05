# Copyright 2025 Automate the Cloud Inc.
# SPDX-License-Identifier: Apache-2.0

# Two resources for one table, because Terraform cannot switch `ignore_changes` on and off
# with an input. Exactly one exists: `this` for on-demand and fixed capacity, `autoscaled`
# when Application Auto Scaling sets the capacity, so that Terraform does not set it back
# on every apply. Keep their arguments identical. Switching between them needs a `moved`
# block in the caller's configuration (see the README).
resource "aws_dynamodb_table" "this" {
  count = local.autoscaled ? 0 : 1

  region = var.region

  name                        = var.name
  billing_mode                = var.billing_mode
  read_capacity               = local.read_capacity
  write_capacity              = local.write_capacity
  hash_key                    = var.hash_key.name
  range_key                   = try(var.range_key.name, null)
  table_class                 = var.table_class
  deletion_protection_enabled = var.deletion_protection_enabled
  stream_enabled              = var.stream_view_type != null
  stream_view_type            = var.stream_view_type

  dynamic "attribute" {
    for_each = local.attributes
    content {
      name = attribute.key
      type = attribute.value
    }
  }

  dynamic "local_secondary_index" {
    for_each = var.local_secondary_indexes
    content {
      name               = local_secondary_index.key
      range_key          = local_secondary_index.value.range_key.name
      projection_type    = local_secondary_index.value.projection_type
      non_key_attributes = local_secondary_index.value.projection_type == "INCLUDE" ? local_secondary_index.value.non_key_attributes : null
    }
  }

  point_in_time_recovery {
    enabled                 = var.point_in_time_recovery.enabled
    recovery_period_in_days = var.point_in_time_recovery.recovery_period_in_days
  }

  server_side_encryption {
    enabled     = var.server_side_encryption.enabled
    kms_key_arn = var.server_side_encryption.kms_key_arn
  }

  ttl {
    enabled        = try(var.ttl.enabled, false)
    attribute_name = try(var.ttl.attribute_name, null)
  }

  dynamic "replica" {
    for_each = var.replicas
    content {
      region_name                 = replica.key
      kms_key_arn                 = replica.value.kms_key_arn
      point_in_time_recovery      = coalesce(replica.value.point_in_time_recovery, var.point_in_time_recovery.enabled)
      deletion_protection_enabled = coalesce(replica.value.deletion_protection_enabled, var.deletion_protection_enabled)
      propagate_tags              = replica.value.propagate_tags
    }
  }

  tags = local.table_tags

  timeouts {
    create = var.timeouts.create
    update = var.timeouts.update
    delete = var.timeouts.delete
  }

  lifecycle {
    precondition {
      condition     = !contains(keys(var.replicas), data.aws_region.this.region)
      error_message = "replicas cannot include the table's own Region."
    }
  }
}

resource "aws_dynamodb_table" "autoscaled" {
  count = local.autoscaled ? 1 : 0

  region = var.region

  name                        = var.name
  billing_mode                = var.billing_mode
  read_capacity               = local.read_capacity
  write_capacity              = local.write_capacity
  hash_key                    = var.hash_key.name
  range_key                   = try(var.range_key.name, null)
  table_class                 = var.table_class
  deletion_protection_enabled = var.deletion_protection_enabled
  stream_enabled              = var.stream_view_type != null
  stream_view_type            = var.stream_view_type

  dynamic "attribute" {
    for_each = local.attributes
    content {
      name = attribute.key
      type = attribute.value
    }
  }

  dynamic "local_secondary_index" {
    for_each = var.local_secondary_indexes
    content {
      name               = local_secondary_index.key
      range_key          = local_secondary_index.value.range_key.name
      projection_type    = local_secondary_index.value.projection_type
      non_key_attributes = local_secondary_index.value.projection_type == "INCLUDE" ? local_secondary_index.value.non_key_attributes : null
    }
  }

  point_in_time_recovery {
    enabled                 = var.point_in_time_recovery.enabled
    recovery_period_in_days = var.point_in_time_recovery.recovery_period_in_days
  }

  server_side_encryption {
    enabled     = var.server_side_encryption.enabled
    kms_key_arn = var.server_side_encryption.kms_key_arn
  }

  ttl {
    enabled        = try(var.ttl.enabled, false)
    attribute_name = try(var.ttl.attribute_name, null)
  }

  dynamic "replica" {
    for_each = var.replicas
    content {
      region_name                 = replica.key
      kms_key_arn                 = replica.value.kms_key_arn
      point_in_time_recovery      = coalesce(replica.value.point_in_time_recovery, var.point_in_time_recovery.enabled)
      deletion_protection_enabled = coalesce(replica.value.deletion_protection_enabled, var.deletion_protection_enabled)
      propagate_tags              = replica.value.propagate_tags
    }
  }

  tags = local.table_tags

  timeouts {
    create = var.timeouts.create
    update = var.timeouts.update
    delete = var.timeouts.delete
  }

  lifecycle {
    precondition {
      condition     = !contains(keys(var.replicas), data.aws_region.this.region)
      error_message = "replicas cannot include the table's own Region."
    }

    ignore_changes = [read_capacity, write_capacity]
  }
}
