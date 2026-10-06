# Copyright 2026 Automate the Cloud Inc.
# SPDX-License-Identifier: Apache-2.0

# Target tracking: Application Auto Scaling keeps the share of capacity in use near
# target_value, through CloudWatch alarms that it creates and deletes with the policy.
resource "aws_appautoscaling_policy" "this" {
  for_each = local.autoscaling_dimensions

  region = var.region

  name               = "${each.value.metric}:${aws_appautoscaling_target.this[each.key].resource_id}"
  policy_type        = "TargetTrackingScaling"
  service_namespace  = aws_appautoscaling_target.this[each.key].service_namespace
  resource_id        = aws_appautoscaling_target.this[each.key].resource_id
  scalable_dimension = aws_appautoscaling_target.this[each.key].scalable_dimension

  target_tracking_scaling_policy_configuration {
    predefined_metric_specification {
      predefined_metric_type = each.value.metric
    }

    target_value       = each.value.settings.target_value
    scale_in_cooldown  = each.value.settings.scale_in_cooldown
    scale_out_cooldown = each.value.settings.scale_out_cooldown
  }
}
