resource "aws_appautoscaling_target" "table_read" {
  count = (var.autoscaling.enabled && length(var.autoscaling.read) > 0 ? 1 : 0)

  max_capacity       = var.autoscaling.read["max_capacity"]
  min_capacity       = var.read_capacity
  resource_id        = "table/${aws_dynamodb_table.this.name}"
  scalable_dimension = "dynamodb:table:ReadCapacityUnits"
  service_namespace  = "dynamodb"
  provider           = aws.this
}

resource "aws_appautoscaling_policy" "table_read_policy" {
  count = (var.autoscaling.enabled && length(var.autoscaling.read) > 0 ? 1 : 0)

  name               = "DynamoDBReadCapacityUtilization:${aws_appautoscaling_target.table_read[0].resource_id}"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.table_read[0].resource_id
  scalable_dimension = aws_appautoscaling_target.table_read[0].scalable_dimension
  service_namespace  = aws_appautoscaling_target.table_read[0].service_namespace

  target_tracking_scaling_policy_configuration {
    predefined_metric_specification {
      predefined_metric_type = "DynamoDBReadCapacityUtilization"
    }

    scale_in_cooldown  = lookup(var.autoscaling.read, "scale_in_cooldown", var.autoscaling.defaults["scale_in_cooldown"])
    scale_out_cooldown = lookup(var.autoscaling.read, "scale_out_cooldown", var.autoscaling.defaults["scale_out_cooldown"])
    target_value       = lookup(var.autoscaling.read, "target_value", var.autoscaling.defaults["target_value"])
  }
  provider = aws.this
}

resource "aws_appautoscaling_target" "table_write" {
  count = (var.autoscaling.enabled && length(var.autoscaling.write) > 0 ? 1 : 0)

  max_capacity       = var.autoscaling.write["max_capacity"]
  min_capacity       = var.write_capacity
  resource_id        = "table/${aws_dynamodb_table.this.name}"
  scalable_dimension = "dynamodb:table:WriteCapacityUnits"
  service_namespace  = "dynamodb"
  provider           = aws.this
}

resource "aws_appautoscaling_policy" "table_write_policy" {
  count = (var.autoscaling.enabled && length(var.autoscaling.write) > 0 ? 1 : 0)

  name               = "DynamoDBWriteCapacityUtilization:${aws_appautoscaling_target.table_write[0].resource_id}"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.table_write[0].resource_id
  scalable_dimension = aws_appautoscaling_target.table_write[0].scalable_dimension
  service_namespace  = aws_appautoscaling_target.table_write[0].service_namespace

  target_tracking_scaling_policy_configuration {
    predefined_metric_specification {
      predefined_metric_type = "DynamoDBWriteCapacityUtilization"
    }

    scale_in_cooldown  = lookup(var.autoscaling.read, "scale_in_cooldown", var.autoscaling.defaults["scale_in_cooldown"])
    scale_out_cooldown = lookup(var.autoscaling.read, "scale_out_cooldown", var.autoscaling.defaults["scale_out_cooldown"])
    target_value       = lookup(var.autoscaling.read, "target_value", var.autoscaling.defaults["target_value"])
  }
  provider = aws.this
}

resource "aws_appautoscaling_target" "index_read" {
  for_each = (var.autoscaling.enabled ? var.autoscaling.indexes : {})

  max_capacity       = each.value["read_max_capacity"]
  min_capacity       = each.value["read_min_capacity"]
  resource_id        = "table/${aws_dynamodb_table.this.name}/index/${each.key}"
  scalable_dimension = "dynamodb:index:ReadCapacityUnits"
  service_namespace  = "dynamodb"
  provider           = aws.this
}

resource "aws_appautoscaling_policy" "index_read_policy" {
  for_each = (var.autoscaling.enabled ? var.autoscaling.indexes : {})

  name               = "DynamoDBReadCapacityUtilization:${aws_appautoscaling_target.index_read[each.key].resource_id}"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.index_read[each.key].resource_id
  scalable_dimension = aws_appautoscaling_target.index_read[each.key].scalable_dimension
  service_namespace  = aws_appautoscaling_target.index_read[each.key].service_namespace

  target_tracking_scaling_policy_configuration {
    predefined_metric_specification {
      predefined_metric_type = "DynamoDBReadCapacityUtilization"
    }

    scale_in_cooldown  = merge(var.autoscaling.defaults, each.value)["scale_in_cooldown"]
    scale_out_cooldown = merge(var.autoscaling.defaults, each.value)["scale_out_cooldown"]
    target_value       = merge(var.autoscaling.defaults, each.value)["target_value"]
  }
  provider = aws.this
}

resource "aws_appautoscaling_target" "index_write" {
  for_each = (var.autoscaling.enabled ? var.autoscaling.indexes : {})

  max_capacity       = each.value["write_max_capacity"]
  min_capacity       = each.value["write_min_capacity"]
  resource_id        = "table/${aws_dynamodb_table.this.name}/index/${each.key}"
  scalable_dimension = "dynamodb:index:WriteCapacityUnits"
  service_namespace  = "dynamodb"
  provider           = aws.this
}

resource "aws_appautoscaling_policy" "index_write_policy" {
  for_each = (var.autoscaling.enabled ? var.autoscaling.indexes : {})

  name               = "DynamoDBWriteCapacityUtilization:${aws_appautoscaling_target.index_write[each.key].resource_id}"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.index_write[each.key].resource_id
  scalable_dimension = aws_appautoscaling_target.index_write[each.key].scalable_dimension
  service_namespace  = aws_appautoscaling_target.index_write[each.key].service_namespace

  target_tracking_scaling_policy_configuration {
    predefined_metric_specification {
      predefined_metric_type = "DynamoDBWriteCapacityUtilization"
    }

    scale_in_cooldown  = merge(var.autoscaling.defaults, each.value)["scale_in_cooldown"]
    scale_out_cooldown = merge(var.autoscaling.defaults, each.value)["scale_out_cooldown"]
    target_value       = merge(var.autoscaling.defaults, each.value)["target_value"]
  }
  provider = aws.this
}
