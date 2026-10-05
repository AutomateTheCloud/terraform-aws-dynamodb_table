# Copyright 2025 Automate the Cloud Inc.
# SPDX-License-Identifier: Apache-2.0

resource "aws_appautoscaling_target" "this" {
  for_each = local.autoscaling_dimensions

  region = var.region

  service_namespace  = "dynamodb"
  resource_id        = each.value.resource_id
  scalable_dimension = each.value.scalable_dimension
  min_capacity       = each.value.settings.min_capacity
  max_capacity       = each.value.settings.max_capacity

  tags = local.table_tags
}
