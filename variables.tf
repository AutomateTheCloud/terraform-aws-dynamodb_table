# Copyright 2025 Automate the Cloud Inc.
# SPDX-License-Identifier: Apache-2.0

variable "autoscaling" {
  description = <<-EOT
    Turns on autoscaling of the table's read and write capacity. Requires `billing_mode = "PROVISIONED"`. The default, `null`, means fixed capacity, set by `read_capacity` and `write_capacity`.

    Decide when you create the table. An autoscaled table is a different resource in the module, so that Terraform leaves its capacity to Application Auto Scaling. Turning autoscaling on or off later replaces the table unless you add a `moved` block to your configuration; see [Turning autoscaling on or off later](https://github.com/AutomateTheCloud/terraform-aws-dynamodb_table#turning-autoscaling-on-or-off-later).

    - `read` - (Required) Settings for read capacity units.
    - `write` - (Required) Settings for write capacity units.

    Each takes:

    - `min_capacity` - (Required) The fewest capacity units. The table is created with this many. At least 1.
    - `max_capacity` - (Required) The most capacity units. At least `min_capacity`.
    - `target_value` - (Optional) The percentage of the capacity that should be in use, from 20 to 90. Defaults to `70`.
    - `scale_in_cooldown` - (Optional) Seconds to wait after a scale-in before the next one. Defaults to `0`.
    - `scale_out_cooldown` - (Optional) Seconds to wait after a scale-out before the next one. Defaults to `0`.
  EOT
  type = object({
    read = object({
      min_capacity       = number
      max_capacity       = number
      target_value       = optional(number, 70)
      scale_in_cooldown  = optional(number, 0)
      scale_out_cooldown = optional(number, 0)
    })
    write = object({
      min_capacity       = number
      max_capacity       = number
      target_value       = optional(number, 70)
      scale_in_cooldown  = optional(number, 0)
      scale_out_cooldown = optional(number, 0)
    })
  })
  default = null

  validation {
    condition     = var.autoscaling == null || var.billing_mode == "PROVISIONED"
    error_message = "autoscaling needs billing_mode = \"PROVISIONED\". An on-demand (PAY_PER_REQUEST) table scales by itself."
  }

  validation {
    condition = alltrue([
      for s in(var.autoscaling == null ? [] : [var.autoscaling.read, var.autoscaling.write]) :
      s.min_capacity >= 1 && s.max_capacity >= s.min_capacity && s.target_value >= 20 && s.target_value <= 90 && s.scale_in_cooldown >= 0 && s.scale_out_cooldown >= 0
    ])
    error_message = "In autoscaling.read and autoscaling.write: min_capacity must be at least 1, max_capacity at least min_capacity, target_value from 20 to 90, and the cooldowns 0 or more."
  }
}

variable "billing_mode" {
  description = <<-EOT
    How you pay for reads and writes:

    - `PAY_PER_REQUEST` (default) - On demand: you pay for each request, and the table scales by itself.
    - `PROVISIONED` - You set the read and write capacity units, in `read_capacity` and `write_capacity` or with `autoscaling`, and pay for them whether or not they are used.

    You can change it later without replacing the table, but with global secondary indexes it takes extra steps; see [Changing the billing mode](https://github.com/AutomateTheCloud/terraform-aws-dynamodb_table#changing-the-billing-mode).
  EOT
  type        = string
  default     = "PAY_PER_REQUEST"
  nullable    = false

  validation {
    condition     = contains(["PAY_PER_REQUEST", "PROVISIONED"], var.billing_mode)
    error_message = "billing_mode must be PAY_PER_REQUEST or PROVISIONED."
  }
}

variable "deletion_protection_enabled" {
  description = <<-EOT
    Whether AWS refuses to delete the table and its replicas. Defaults to `true`, so a plan that would replace or destroy the table fails at apply, and the table keeps its items; its global secondary indexes are deleted before that, and applying the original configuration again rebuilds them. To delete the table, set it to `false` and apply first.
  EOT
  type        = bool
  default     = true
  nullable    = false
}

variable "details" {
  description = <<-EOT
    Names and tags shared by every resource in the module. `scope`, `purpose` and `environment` become the `Scope`, `Purpose` and `Environment` tags, and are converted to abbreviations that other modules can use in resource names (see the `metadata` output). [The `details` input](https://github.com/AutomateTheCloud/terraform-aws-dynamodb_table#the-details-input) explains why it is required.

    - `scope` - (Required) What the resource belongs to, such as an organization or project: `Automate the Cloud`.
    - `purpose` - (Required) What the resource is for: `Web Site`.
    - `environment` - (Required) The environment: `Production`.
    - `scope_abbr`, `purpose_abbr`, `environment_abbr` - (Optional) Abbreviations to use instead of the generated ones, which are lowercase with words joined by underscores (`Web Site` becomes `web_site`).
    - `additional_tags` - (Optional) More tags for every resource, such as `{ CostCenter = "1234" }`.
  EOT
  type = object({
    scope            = string
    scope_abbr       = optional(string)
    purpose          = string
    purpose_abbr     = optional(string)
    environment      = string
    environment_abbr = optional(string)
    additional_tags  = optional(map(string), {})
  })
  nullable = false

  validation {
    condition     = trimspace(var.details.scope) != ""
    error_message = "Scope not specified."
  }

  validation {
    condition     = trimspace(var.details.purpose) != ""
    error_message = "Purpose not specified."
  }

  validation {
    condition     = trimspace(var.details.environment) != ""
    error_message = "Environment not specified."
  }
}

variable "global_secondary_indexes" {
  description = <<-EOT
    Global secondary indexes, keyed by index name. Each lets you query the table by other attributes than its own keys. You can add and remove them at any time. Defaults to none.

    - `hash_key` - (Required) The index's partition key: `{ name = "GameTitle", type = "S" }`. `type` is `S` (string), `N` (number) or `B` (binary).
    - `range_key` - (Optional) The index's sort key, in the same form. Defaults to none.
    - `projection_type` - (Optional) Which attributes are copied into the index: `ALL` (default), `KEYS_ONLY`, or `INCLUDE` for the keys plus `non_key_attributes`.
    - `non_key_attributes` - (Optional) With `INCLUDE` only, and required with it: the other attributes to copy into the index.
    - `read_capacity`, `write_capacity` - (Optional) With `billing_mode = "PROVISIONED"` and no `autoscaling`, and required then: the index's capacity units. Leave them out for an on-demand table.
    - `autoscaling` - (Optional) Autoscaling of the index's capacity, with `read` and `write` in the same form as the module's `autoscaling` input. Needs `billing_mode = "PROVISIONED"`. As for the table, decide when you create the index: turning it on or off later replaces the index unless you add a `moved` block.

    An attribute used as a key by several indexes, or by the table and an index, must have the same type everywhere.
  EOT
  type = map(object({
    hash_key = object({
      name = string
      type = string
    })
    range_key = optional(object({
      name = string
      type = string
    }))
    projection_type    = optional(string, "ALL")
    non_key_attributes = optional(list(string), [])
    read_capacity      = optional(number)
    write_capacity     = optional(number)
    autoscaling = optional(object({
      read = object({
        min_capacity       = number
        max_capacity       = number
        target_value       = optional(number, 70)
        scale_in_cooldown  = optional(number, 0)
        scale_out_cooldown = optional(number, 0)
      })
      write = object({
        min_capacity       = number
        max_capacity       = number
        target_value       = optional(number, 70)
        scale_in_cooldown  = optional(number, 0)
        scale_out_cooldown = optional(number, 0)
      })
    }))
  }))
  default  = {}
  nullable = false

  validation {
    condition     = alltrue([for k in keys(var.global_secondary_indexes) : can(regex("^[A-Za-z0-9_.-]{3,255}$", k))])
    error_message = "Each global secondary index name must be 3 to 255 characters: letters, numbers, underscores (_), hyphens (-) and periods (.)."
  }

  validation {
    condition = alltrue(flatten([for i in values(var.global_secondary_indexes) : [
      for key in concat([i.hash_key], i.range_key == null ? [] : [i.range_key]) : key.name != "" && contains(["S", "N", "B"], key.type)
    ]]))
    error_message = "Each global secondary index key needs a name, and a type of S, N or B."
  }

  validation {
    condition = alltrue([for i in values(var.global_secondary_indexes) :
      i.range_key == null || try(i.range_key.name != i.hash_key.name, true)
    ])
    error_message = "A global secondary index's hash_key and range_key must be different attributes."
  }

  validation {
    condition = alltrue([for i in values(var.global_secondary_indexes) :
      contains(["ALL", "KEYS_ONLY", "INCLUDE"], i.projection_type) && (i.projection_type == "INCLUDE") == (length(i.non_key_attributes) > 0)
    ])
    error_message = "Each global secondary index's projection_type must be ALL, KEYS_ONLY or INCLUDE, and non_key_attributes must be given with INCLUDE, and only with INCLUDE."
  }

  validation {
    condition = alltrue([for i in values(var.global_secondary_indexes) :
      var.billing_mode == "PROVISIONED" ? (
        i.autoscaling == null ? (try(i.read_capacity >= 1, false) && try(i.write_capacity >= 1, false)) : (i.read_capacity == null && i.write_capacity == null)
      ) : (i.read_capacity == null && i.write_capacity == null && i.autoscaling == null)
    ])
    error_message = "With billing_mode = \"PROVISIONED\", each global secondary index needs either read_capacity and write_capacity (at least 1 each) or autoscaling, not both. With PAY_PER_REQUEST, leave out read_capacity, write_capacity and autoscaling."
  }

  validation {
    condition = alltrue(flatten([for i in values(var.global_secondary_indexes) : [
      for s in(i.autoscaling == null ? [] : [i.autoscaling.read, i.autoscaling.write]) :
      s.min_capacity >= 1 && s.max_capacity >= s.min_capacity && s.target_value >= 20 && s.target_value <= 90 && s.scale_in_cooldown >= 0 && s.scale_out_cooldown >= 0
    ]]))
    error_message = "In each global secondary index's autoscaling.read and autoscaling.write: min_capacity must be at least 1, max_capacity at least min_capacity, target_value from 20 to 90, and the cooldowns 0 or more."
  }

  validation {
    condition     = length(setintersection(keys(var.global_secondary_indexes), keys(var.local_secondary_indexes))) == 0
    error_message = "A global secondary index cannot have the same name as a local secondary index."
  }

  validation {
    condition = alltrue([
      for name, types in {
        for key in concat(
          [var.hash_key],
          var.range_key == null ? [] : [var.range_key],
          [for l in values(var.local_secondary_indexes) : l.range_key],
          flatten([for i in values(var.global_secondary_indexes) : concat([i.hash_key], i.range_key == null ? [] : [i.range_key])]),
        ) : key.name => key.type...
      } : length(distinct(types)) == 1
    ])
    error_message = "An attribute used as a key by the table and its indexes must have the same type everywhere."
  }
}

variable "hash_key" {
  description = <<-EOT
    The table's partition key, which every item must have: `{ name = "UserId", type = "S" }`. `type` is `S` (string), `N` (number) or `B` (binary). Changing it replaces the table.
  EOT
  type = object({
    name = string
    type = string
  })
  nullable = false

  validation {
    condition     = var.hash_key.name != "" && contains(["S", "N", "B"], var.hash_key.type)
    error_message = "hash_key needs a name, and a type of S, N or B."
  }
}

variable "local_secondary_indexes" {
  description = <<-EOT
    Local secondary indexes, keyed by index name. Each sorts the items of one partition key by another attribute. The table needs a `range_key`, and AWS allows at most 5. Defaults to none.

    AWS creates local secondary indexes only with the table: adding, changing or removing one replaces the table, and its data is lost. Use a global secondary index for anything you may add later.

    - `range_key` - (Required) The index's sort key: `{ name = "Score", type = "N" }`. `type` is `S` (string), `N` (number) or `B` (binary).
    - `projection_type` - (Optional) Which attributes are copied into the index: `ALL` (default), `KEYS_ONLY`, or `INCLUDE` for the keys plus `non_key_attributes`.
    - `non_key_attributes` - (Optional) With `INCLUDE` only, and required with it: the other attributes to copy into the index.
  EOT
  type = map(object({
    range_key = object({
      name = string
      type = string
    })
    projection_type    = optional(string, "ALL")
    non_key_attributes = optional(list(string), [])
  }))
  default  = {}
  nullable = false

  validation {
    condition     = alltrue([for k in keys(var.local_secondary_indexes) : can(regex("^[A-Za-z0-9_.-]{3,255}$", k))])
    error_message = "Each local secondary index name must be 3 to 255 characters: letters, numbers, underscores (_), hyphens (-) and periods (.)."
  }

  validation {
    condition     = length(var.local_secondary_indexes) == 0 || var.range_key != null
    error_message = "Local secondary indexes need a table with a range_key."
  }

  validation {
    condition     = length(var.local_secondary_indexes) <= 5
    error_message = "AWS allows at most 5 local secondary indexes per table."
  }

  validation {
    condition = alltrue([for l in values(var.local_secondary_indexes) :
      l.range_key.name != "" && contains(["S", "N", "B"], l.range_key.type) && l.range_key.name != var.hash_key.name
    ])
    error_message = "Each local secondary index's range_key needs a name other than the table's hash_key, and a type of S, N or B."
  }

  validation {
    condition = alltrue([for l in values(var.local_secondary_indexes) :
      contains(["ALL", "KEYS_ONLY", "INCLUDE"], l.projection_type) && (l.projection_type == "INCLUDE") == (length(l.non_key_attributes) > 0)
    ])
    error_message = "Each local secondary index's projection_type must be ALL, KEYS_ONLY or INCLUDE, and non_key_attributes must be given with INCLUDE, and only with INCLUDE."
  }
}

variable "name" {
  description = <<-EOT
    The table's name, unique in the account and Region: 3 to 255 letters, numbers, underscores (_), hyphens (-) and periods (.). Changing it replaces the table.
  EOT
  type        = string
  nullable    = false

  validation {
    condition     = can(regex("^[A-Za-z0-9_.-]{3,255}$", var.name))
    error_message = "name must be 3 to 255 characters: letters, numbers, underscores (_), hyphens (-) and periods (.)."
  }
}

variable "point_in_time_recovery" {
  description = <<-EOT
    Continuous backups, from which the table can be restored to any second in the recovery period, to a new table. On by default. AWS charges for them by the size of the table.

    - `enabled` - (Optional) Defaults to `true`.
    - `recovery_period_in_days` - (Optional) How far back a restore can go, from 1 to 35 days. Defaults to AWS's default, 35. It applies to this table, not to its `replicas`, which keep 35 days.
  EOT
  type = object({
    enabled                 = optional(bool, true)
    recovery_period_in_days = optional(number)
  })
  default  = {}
  nullable = false

  validation {
    condition     = var.point_in_time_recovery.recovery_period_in_days == null || (var.point_in_time_recovery.enabled && try(var.point_in_time_recovery.recovery_period_in_days >= 1 && var.point_in_time_recovery.recovery_period_in_days <= 35 && floor(var.point_in_time_recovery.recovery_period_in_days) == var.point_in_time_recovery.recovery_period_in_days, false))
    error_message = "point_in_time_recovery.recovery_period_in_days must be a whole number from 1 to 35, and needs enabled = true."
  }
}

variable "range_key" {
  description = <<-EOT
    The table's sort key, in the same form as `hash_key`. Items with the same partition key are stored in its order. Defaults to none. Changing it replaces the table.
  EOT
  type = object({
    name = string
    type = string
  })
  default = null

  validation {
    condition     = var.range_key == null || try(var.range_key.name != "" && contains(["S", "N", "B"], var.range_key.type), false)
    error_message = "range_key needs a name, and a type of S, N or B."
  }

  validation {
    condition     = var.range_key == null || try(var.range_key.name != var.hash_key.name, true)
    error_message = "hash_key and range_key must be different attributes."
  }
}

variable "read_capacity" {
  description = <<-EOT
    The table's read capacity units, with `billing_mode = "PROVISIONED"` and no `autoscaling`, and required then. Leave it out for an on-demand table or with `autoscaling`.
  EOT
  type        = number
  default     = null

  validation {
    condition     = (var.billing_mode == "PROVISIONED" && var.autoscaling == null) ? try(var.read_capacity >= 1, false) : var.read_capacity == null
    error_message = "read_capacity (at least 1) is required with billing_mode = \"PROVISIONED\" and no autoscaling, and must be left out otherwise."
  }
}

variable "region" {
  description = <<-EOT
    The AWS Region to create the table and its indexes in, such as `us-west-2`. Defaults to the Region of the AWS provider passed to the module.
  EOT
  type        = string
  default     = null
}

variable "replicas" {
  description = <<-EOT
    Copies of the table in other Regions, keyed by Region name, such as `us-west-2`. The table becomes a global table: each copy can be read and written, and DynamoDB keeps them in step. Defaults to none.

    Replicas need `billing_mode = "PAY_PER_REQUEST"` and a `stream_view_type`: AWS turns a stream on when it adds a replica to a table without one, and the module keeps its configuration in step with that. With a customer managed key in `server_side_encryption`, every replica needs its own key, in its own Region.

    - `kms_key_arn` - (Optional) The ARN of the customer managed key for this replica. Changing it replaces the replica.
    - `point_in_time_recovery` - (Optional) Whether the replica has point-in-time recovery. Defaults to the table's `point_in_time_recovery.enabled`. A replica keeps AWS's 35-day recovery period: `point_in_time_recovery.recovery_period_in_days` applies to the table only.
    - `deletion_protection_enabled` - (Optional) Defaults to the table's `deletion_protection_enabled`.
    - `propagate_tags` - (Optional) Whether the replica gets the table's tags. Defaults to `true`.
  EOT
  type = map(object({
    kms_key_arn                 = optional(string)
    point_in_time_recovery      = optional(bool)
    deletion_protection_enabled = optional(bool)
    propagate_tags              = optional(bool, true)
  }))
  default  = {}
  nullable = false

  validation {
    condition     = alltrue([for r in keys(var.replicas) : can(regex("^[a-z]{2}(-[a-z]+)+-[0-9]+$", r))])
    error_message = "Each replicas key must be a Region name, such as us-west-2."
  }

  validation {
    condition     = length(var.replicas) == 0 || (var.billing_mode == "PAY_PER_REQUEST" && var.stream_view_type != null)
    error_message = "replicas need billing_mode = \"PAY_PER_REQUEST\" and a stream_view_type, such as NEW_AND_OLD_IMAGES."
  }

  validation {
    condition     = alltrue([for r in values(var.replicas) : (r.kms_key_arn != null) == (try(var.server_side_encryption.kms_key_arn, null) != null)])
    error_message = "With a customer managed key in server_side_encryption.kms_key_arn, every replica needs its own kms_key_arn; without one, leave the replicas' kms_key_arn out."
  }
}

variable "server_side_encryption" {
  description = <<-EOT
    The key the table is encrypted with. DynamoDB always encrypts tables; this chooses the key.

    - `enabled` - (Optional) Defaults to `true`: the AWS managed key `aws/dynamodb` in your account, or the key in `kms_key_arn`. Each use of the key is recorded in AWS CloudTrail. `false` means a key that AWS owns and that does not appear in your account.
    - `kms_key_arn` - (Optional) The ARN of a customer managed key, such as one created with the Automate the Cloud KMS key module. Needs `enabled = true`. Defaults to none.
  EOT
  type = object({
    enabled     = optional(bool, true)
    kms_key_arn = optional(string)
  })
  default  = {}
  nullable = false

  validation {
    condition     = var.server_side_encryption.kms_key_arn == null || (var.server_side_encryption.enabled && can(regex("^arn:[a-z-]+:kms:", var.server_side_encryption.kms_key_arn)))
    error_message = "server_side_encryption.kms_key_arn must be a KMS key ARN, and needs enabled = true."
  }
}

variable "stream_view_type" {
  description = <<-EOT
    Turns on DynamoDB Streams, a log of every change to the table's items, and chooses what each record holds: `KEYS_ONLY`, `NEW_IMAGE`, `OLD_IMAGE` or `NEW_AND_OLD_IMAGES`. Defaults to `null`: no stream.
  EOT
  type        = string
  default     = null

  validation {
    condition     = var.stream_view_type == null || contains(["KEYS_ONLY", "NEW_IMAGE", "OLD_IMAGE", "NEW_AND_OLD_IMAGES"], coalesce(var.stream_view_type, "-"))
    error_message = "stream_view_type must be KEYS_ONLY, NEW_IMAGE, OLD_IMAGE or NEW_AND_OLD_IMAGES."
  }
}

variable "table_class" {
  description = <<-EOT
    The storage class: `STANDARD` (default), or `STANDARD_INFREQUENT_ACCESS` for a table that stores much and is read little, with cheaper storage and dearer reads and writes. You can change it later, in place.
  EOT
  type        = string
  default     = "STANDARD"
  nullable    = false

  validation {
    condition     = contains(["STANDARD", "STANDARD_INFREQUENT_ACCESS"], var.table_class)
    error_message = "table_class must be STANDARD or STANDARD_INFREQUENT_ACCESS."
  }
}

variable "timeouts" {
  description = <<-EOT
    How long Terraform waits for the table, and for each global secondary index, to be created, updated or deleted, such as `"2h"`. Building an index on a large table can take hours. Each defaults to the AWS provider's default.

    - `create` - (Optional)
    - `update` - (Optional)
    - `delete` - (Optional)
  EOT
  type = object({
    create = optional(string)
    update = optional(string)
    delete = optional(string)
  })
  default  = {}
  nullable = false
}

variable "ttl" {
  description = <<-EOT
    Turns on time to live (TTL): DynamoDB deletes each item some time after the moment stored in `attribute_name`, a number of seconds since 1970 (Unix epoch time). Items without the attribute are kept. Defaults to `null`: TTL off.

    - `attribute_name` - (Required) The attribute that holds each item's expiry time.
    - `enabled` - (Optional) Defaults to `true`. To turn TTL off once it has been on, set `enabled = false` and keep `attribute_name`: AWS needs the attribute's name to turn TTL off, so setting `ttl` back to `null` fails.
  EOT
  type = object({
    attribute_name = string
    enabled        = optional(bool, true)
  })
  default = null

  validation {
    condition     = var.ttl == null || try(length(var.ttl.attribute_name) >= 1 && length(var.ttl.attribute_name) <= 255, false)
    error_message = "ttl.attribute_name must be 1 to 255 characters."
  }
}

variable "write_capacity" {
  description = <<-EOT
    The table's write capacity units, with `billing_mode = "PROVISIONED"` and no `autoscaling`, and required then. Leave it out for an on-demand table or with `autoscaling`.
  EOT
  type        = number
  default     = null

  validation {
    condition     = (var.billing_mode == "PROVISIONED" && var.autoscaling == null) ? try(var.write_capacity >= 1, false) : var.write_capacity == null
    error_message = "write_capacity (at least 1) is required with billing_mode = \"PROVISIONED\" and no autoscaling, and must be left out otherwise."
  }
}
