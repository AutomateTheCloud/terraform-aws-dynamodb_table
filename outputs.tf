# Copyright 2026 Automate the Cloud Inc.
# SPDX-License-Identifier: Apache-2.0

output "metadata" {
  description = <<-EOT
    Everything the module created, in one object, so that other configurations need only one reference:

    - `details` - The scope, purpose and environment, each with its `name`, `abbr` (lowercase, words joined by underscores) and `machine` (lowercase letters and numbers only) forms, and the `tags` applied to every resource.
    - `aws` - The `account.id`, and the `region` `name`, `abbr` (such as `use1` for `us-east-1`) and `description`.
    - `dynamodb_table` - The table's `name` (also its `id`), `arn`, `hash_key`, `range_key`, `billing_mode`, `stream_arn` and `stream_label` (when `stream_view_type` is set), `replica` (each with its `region_name`, `arn` and `stream_arn`), `tags` and the rest of its attributes. `read_capacity` and `write_capacity` are `null` when `autoscaling` sets them; see `appautoscaling_target`.
    - `dynamodb_global_secondary_index` - The global secondary indexes, keyed like `global_secondary_indexes`, each with its `index_name`, `arn`, `key_schema`, `projection` and `provisioned_throughput` (`null` for an autoscaled index), or `null` when there are none.
    - `appautoscaling_target` - The Application Auto Scaling targets, keyed `table/read`, `table/write`, `index/<index name>/read` and `index/<index name>/write`, each with its `resource_id`, `scalable_dimension`, `min_capacity`, `max_capacity` and the rest of its attributes, or `null` when nothing is autoscaled.
    - `appautoscaling_policy` - The target tracking policies, keyed like `appautoscaling_target`, each with its `name`, `arn` and `target_tracking_scaling_policy_configuration`, or `null` when nothing is autoscaled.
  EOT
  value = {
    details = {
      scope = {
        name    = local.scope.name
        abbr    = local.scope.abbr
        machine = local.scope.machine
      }
      purpose = {
        name    = local.purpose.name
        abbr    = local.purpose.abbr
        machine = local.purpose.machine
      }
      environment = {
        name    = local.environment.name
        abbr    = local.environment.abbr
        machine = local.environment.machine
      }
      tags = local.tags
    }

    aws = {
      account = {
        id = local.aws.account.id
      }
      region = {
        name        = local.aws.region.name
        abbr        = local.aws.region.abbr
        description = local.aws.region.description
      }
    }

    # One entry per resource type. Resources that are not created are null.
    appautoscaling_policy           = local.output_resources.appautoscaling_policy
    appautoscaling_target           = local.output_resources.appautoscaling_target
    dynamodb_global_secondary_index = local.output_resources.dynamodb_global_secondary_index
    dynamodb_table                  = local.output_resources.dynamodb_table
  }
}

# Each attribute is listed by name, so that deprecated attributes (such as the table's
# inline global_secondary_index, which the module does not use) never reach callers'
# plans. Restore, import and throughput settings the module does not set are left out.
# So are values that AWS reports differently after the apply, which would make the next
# plan show the output changing: the table's `attribute` set gains each global secondary
# index's keys once the index exists, and `ttl.attribute_name` reads back empty once TTL
# is off. Capacity that Application Auto Scaling sets is null, and the policies' alarm
# ARNs are left out (Application Auto Scaling replaces the alarms whenever the capacity
# changes), so the output does not change each time it scales.
locals {
  output_resources = {
    appautoscaling_policy = length(local.autoscaling_dimensions) == 0 ? null : {
      for k in keys(local.autoscaling_dimensions) : k => {
        arn                                          = aws_appautoscaling_policy.this[k].arn
        id                                           = aws_appautoscaling_policy.this[k].id
        name                                         = aws_appautoscaling_policy.this[k].name
        policy_type                                  = aws_appautoscaling_policy.this[k].policy_type
        region                                       = aws_appautoscaling_policy.this[k].region
        resource_id                                  = aws_appautoscaling_policy.this[k].resource_id
        scalable_dimension                           = aws_appautoscaling_policy.this[k].scalable_dimension
        service_namespace                            = aws_appautoscaling_policy.this[k].service_namespace
        target_tracking_scaling_policy_configuration = aws_appautoscaling_policy.this[k].target_tracking_scaling_policy_configuration
      }
    }

    appautoscaling_target = length(local.autoscaling_dimensions) == 0 ? null : {
      for k in keys(local.autoscaling_dimensions) : k => {
        arn                = aws_appautoscaling_target.this[k].arn
        id                 = aws_appautoscaling_target.this[k].id
        max_capacity       = aws_appautoscaling_target.this[k].max_capacity
        min_capacity       = aws_appautoscaling_target.this[k].min_capacity
        region             = aws_appautoscaling_target.this[k].region
        resource_id        = aws_appautoscaling_target.this[k].resource_id
        role_arn           = aws_appautoscaling_target.this[k].role_arn
        scalable_dimension = aws_appautoscaling_target.this[k].scalable_dimension
        service_namespace  = aws_appautoscaling_target.this[k].service_namespace
        suspended_state    = aws_appautoscaling_target.this[k].suspended_state
        tags               = aws_appautoscaling_target.this[k].tags
        tags_all           = aws_appautoscaling_target.this[k].tags_all
      }
    }

    dynamodb_global_secondary_index = length(var.global_secondary_indexes) == 0 ? null : merge(
      {
        for k in keys(local.global_secondary_indexes_fixed) : k => {
          arn                    = aws_dynamodb_global_secondary_index.this[k].arn
          index_name             = aws_dynamodb_global_secondary_index.this[k].index_name
          key_schema             = aws_dynamodb_global_secondary_index.this[k].key_schema
          projection             = aws_dynamodb_global_secondary_index.this[k].projection
          provisioned_throughput = aws_dynamodb_global_secondary_index.this[k].provisioned_throughput
          region                 = aws_dynamodb_global_secondary_index.this[k].region
          table_name             = aws_dynamodb_global_secondary_index.this[k].table_name
        }
      },
      {
        for k in keys(local.global_secondary_indexes_autoscaled) : k => {
          arn                    = aws_dynamodb_global_secondary_index.autoscaled[k].arn
          index_name             = aws_dynamodb_global_secondary_index.autoscaled[k].index_name
          key_schema             = aws_dynamodb_global_secondary_index.autoscaled[k].key_schema
          projection             = aws_dynamodb_global_secondary_index.autoscaled[k].projection
          provisioned_throughput = null
          region                 = aws_dynamodb_global_secondary_index.autoscaled[k].region
          table_name             = aws_dynamodb_global_secondary_index.autoscaled[k].table_name
        }
      },
    )

    dynamodb_table = local.autoscaled ? {
      arn                         = aws_dynamodb_table.autoscaled[0].arn
      billing_mode                = aws_dynamodb_table.autoscaled[0].billing_mode
      deletion_protection_enabled = aws_dynamodb_table.autoscaled[0].deletion_protection_enabled
      hash_key                    = aws_dynamodb_table.autoscaled[0].hash_key
      id                          = aws_dynamodb_table.autoscaled[0].id
      local_secondary_index       = aws_dynamodb_table.autoscaled[0].local_secondary_index
      name                        = aws_dynamodb_table.autoscaled[0].name
      point_in_time_recovery      = aws_dynamodb_table.autoscaled[0].point_in_time_recovery
      range_key                   = aws_dynamodb_table.autoscaled[0].range_key
      read_capacity               = null
      region                      = aws_dynamodb_table.autoscaled[0].region
      replica                     = aws_dynamodb_table.autoscaled[0].replica
      server_side_encryption      = aws_dynamodb_table.autoscaled[0].server_side_encryption
      stream_arn                  = aws_dynamodb_table.autoscaled[0].stream_arn
      stream_enabled              = aws_dynamodb_table.autoscaled[0].stream_enabled
      stream_label                = aws_dynamodb_table.autoscaled[0].stream_label
      stream_view_type            = aws_dynamodb_table.autoscaled[0].stream_view_type
      table_class                 = aws_dynamodb_table.autoscaled[0].table_class
      tags                        = aws_dynamodb_table.autoscaled[0].tags
      tags_all                    = aws_dynamodb_table.autoscaled[0].tags_all
      write_capacity              = null
      } : {
      arn                         = aws_dynamodb_table.this[0].arn
      billing_mode                = aws_dynamodb_table.this[0].billing_mode
      deletion_protection_enabled = aws_dynamodb_table.this[0].deletion_protection_enabled
      hash_key                    = aws_dynamodb_table.this[0].hash_key
      id                          = aws_dynamodb_table.this[0].id
      local_secondary_index       = aws_dynamodb_table.this[0].local_secondary_index
      name                        = aws_dynamodb_table.this[0].name
      point_in_time_recovery      = aws_dynamodb_table.this[0].point_in_time_recovery
      range_key                   = aws_dynamodb_table.this[0].range_key
      read_capacity               = aws_dynamodb_table.this[0].read_capacity
      region                      = aws_dynamodb_table.this[0].region
      replica                     = aws_dynamodb_table.this[0].replica
      server_side_encryption      = aws_dynamodb_table.this[0].server_side_encryption
      stream_arn                  = aws_dynamodb_table.this[0].stream_arn
      stream_enabled              = aws_dynamodb_table.this[0].stream_enabled
      stream_label                = aws_dynamodb_table.this[0].stream_label
      stream_view_type            = aws_dynamodb_table.this[0].stream_view_type
      table_class                 = aws_dynamodb_table.this[0].table_class
      tags                        = aws_dynamodb_table.this[0].tags
      tags_all                    = aws_dynamodb_table.this[0].tags_all
      write_capacity              = aws_dynamodb_table.this[0].write_capacity
    }
  }
}
