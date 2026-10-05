# Terraform module for Amazon DynamoDB tables

Creates an Amazon DynamoDB table, with its local and global secondary indexes, and optionally a stream, time to live, replicas in other Regions, and autoscaling of provisioned capacity.

The defaults are the settings most tables should have. A table created with only the required inputs is billed on demand, encrypted with the AWS managed key `aws/dynamodb`, backed up continuously with point-in-time recovery, and protected from deletion.

## What it configures

| Setting | Default | Input |
|---|---|---|
| Keys | A partition key, and optionally a sort key | `hash_key`, `range_key` |
| Billing | On demand: pay per request | `billing_mode` |
| Capacity | None; with provisioned billing, fixed or autoscaled | `read_capacity`, `write_capacity`, `autoscaling` |
| Encryption | The AWS managed key `aws/dynamodb` | `server_side_encryption` |
| Point-in-time recovery | On, 35 days | `point_in_time_recovery` |
| Deletion protection | On | `deletion_protection_enabled` |
| Indexes | None | `local_secondary_indexes`, `global_secondary_indexes` |
| Stream of changes | Off | `stream_view_type` |
| Time to live | Off | `ttl` |
| Replicas in other Regions | None | `replicas` |
| Table class | `STANDARD` | `table_class` |

## Usage

```hcl
module "dynamodb_table" {
  source  = "AutomateTheCloud/dynamodb_table/aws"
  version = "~> 1.0"

  details = {
    scope       = "Automate the Cloud"
    purpose     = "Course Progress"
    environment = "Production"
  }

  name      = "course-progress"
  hash_key  = { name = "UserId", type = "S" }
  range_key = { name = "LessonId", type = "S" }
}
```

`details`, `name` and `hash_key` are the only required inputs. `details` sets the `Scope`, `Purpose` and `Environment` tags on the table, and `name` names it. Define only the attributes the table and its indexes use as keys: DynamoDB is schemaless, and every item can have other attributes of its own.

The module uses your default `aws` provider and creates everything in that provider's Region. To create the table somewhere else without configuring another provider, set `region`:

```hcl
module "dynamodb_table_us_west_2" {
  source  = "AutomateTheCloud/dynamodb_table/aws"
  version = "~> 1.0"

  region   = "us-west-2"
  details  = { scope = "Automate the Cloud", purpose = "Course Progress", environment = "Production" }
  name     = "course-progress"
  hash_key = { name = "UserId", type = "S" }
}
```

Because `region` is an ordinary input, one module block can create a table in each of several Regions with `for_each`. Each is a separate table; to keep copies of one table in several Regions, use `replicas` instead.

To use a provider configured for another account, pass it explicitly with `providers = { aws = aws.other_account }`.

## The `details` input

Most modules ask only for what the resource itself needs. This one also requires `details`: three names that say what the table belongs to, what it is for, and which environment it is in. Every Automate the Cloud module takes the same input, and requiring it is deliberate.

```hcl
details = {
  scope       = "Automate the Cloud" # what it belongs to: an organization, team or project
  purpose     = "Web Site"           # what it is for
  environment = "Production"         # which environment
}
```

**Every resource can be traced.** The three names become the `Scope`, `Purpose` and `Environment` tags on every resource the module creates. Months later, anyone looking at a table in the AWS console, or at a line on the bill, can see who it belongs to and why it exists. With cost allocation tags turned on in AWS Billing, the same tags split your bill by project and environment. Because the input is required and checked, no resource can be created without them.

**One definition for a whole stack.** Write `details` once and pass the same value to every module, so the table, the bucket next to it, its encryption key and everything else are tagged alike. Tags you want everywhere, such as a cost center or the Terraform workspace, go in `additional_tags`:

```hcl
locals {
  details = {
    scope           = "Automate the Cloud"
    purpose         = "Web Site"
    environment     = "Production"
    additional_tags = { CostCenter = "1234", IaC = "true" }
  }
}

module "site_sessions" {
  source  = "AutomateTheCloud/dynamodb_table/aws"
  version = "~> 1.0"

  details  = local.details
  name     = "web-site-sessions-production"
  hash_key = { name = "SessionId", type = "S" }
}
```

**Consistent names.** The module turns each name into two short forms other resources can be named with: `abbr`, lowercase with words joined by underscores (`Web Site` becomes `web_site`), and `machine`, lowercase letters and numbers only (`website`), for resources that allow no underscores. It also works out a short form of the Region, such as `use1` for `us-east-1`. Every module derives these the same way, so names stay consistent across a stack. To choose your own short forms, set `scope_abbr`, `purpose_abbr` or `environment_abbr`, for example `environment_abbr = "prd"`.

**One output to reach everything.** All of it comes back in the `metadata` output, along with everything the module created, so a configuration needs only one reference: `module.site_sessions.metadata.dynamodb_table.arn` for the table's ARN, or `module.site_sessions.metadata.aws.region.abbr` for the Region's short form.

## Examples

Each example is a complete configuration you can run with `terraform init` and `terraform apply`.

- [Basic table](https://github.com/AutomateTheCloud/terraform-aws-dynamodb_table/tree/main/examples/basic): an on-demand table with a partition key and a sort key, and the module's defaults.
- [Complete](https://github.com/AutomateTheCloud/terraform-aws-dynamodb_table/tree/main/examples/complete): local and global secondary indexes, a stream, time to live, and a customer managed key.
- [Autoscaling](https://github.com/AutomateTheCloud/terraform-aws-dynamodb_table/tree/main/examples/autoscaling): provisioned capacity that Application Auto Scaling adjusts, for the table and an index.
- [Global table](https://github.com/AutomateTheCloud/terraform-aws-dynamodb_table/tree/main/examples/global-table): the table in one Region and a replica in another.

## Things to know

### Deleting the table

Deletion protection is on by default, so AWS refuses to delete the table, and its replicas, until you turn it off. A plan that would replace or destroy the table then fails at apply, and the table keeps its items. Terraform deletes the table's global secondary indexes before it tries to delete the table, though, so they are gone after the failed apply; applying your original configuration again rebuilds them.

To delete the table on purpose, set `deletion_protection_enabled = false`, apply, and then destroy. With two or more global secondary indexes, destroy with `terraform destroy -parallelism=1`, for the reason in [Global secondary indexes](#global-secondary-indexes).

### What replaces the table

Changing `name`, `hash_key`, `range_key` or `local_secondary_indexes` replaces the table: the old table and all its items are deleted, and an empty one is created. AWS creates local secondary indexes only with the table, so use global secondary indexes for anything you may add later. Changing a replica's `kms_key_arn` replaces that replica.

### Global secondary indexes

Each global secondary index is a separate `aws_dynamodb_global_secondary_index` resource, not a block of the table, so you can add, change and remove indexes without touching the table. Changing an index's keys replaces the index. Building an index takes several minutes even on an empty table, and longer on a large one; raise `timeouts` if Terraform gives up waiting.

**Create or delete several indexes with `-parallelism=1`.** DynamoDB changes one index at a time per table, and the AWS provider does not wait its turn: when one apply creates or deletes two or more indexes, Terraform starts them together, and AWS rejects all but one with `ResourceInUseException: The resource which you are attempting to change is in use`. With `terraform apply -parallelism=1`, or `terraform destroy -parallelism=1`, Terraform handles them one after another. Without it, each new run gets one more index done. This happens the first time you apply a configuration with several indexes, whenever you add or remove several at once, and when you destroy the table.

### Changing the billing mode

Changing `billing_mode` updates the table in place. With global secondary indexes, AWS needs the table and every index changed in one request, which Terraform cannot send, because each index is a separate resource:

- **From on demand to provisioned**, make the change once with the AWS CLI, giving every index its capacity, then apply your new configuration, which then finds nothing to change:

  ```shell
  aws dynamodb update-table --table-name <table> --billing-mode PROVISIONED \
    --provisioned-throughput ReadCapacityUnits=5,WriteCapacityUnits=5 \
    --global-secondary-index-updates '[{"Update":{"IndexName":"<index>","ProvisionedThroughput":{"ReadCapacityUnits":5,"WriteCapacityUnits":5}}}]'
  ```

- **From provisioned to on demand**, apply twice. The first apply changes the table, and AWS drops the indexes' capacity with it; Terraform then reports an error for each index (`ValidationException ... when TableThroughputMode is PAY_PER_REQUEST`). The second apply finds nothing left to change.

### Turning autoscaling on or off later

Terraform cannot leave capacity to Application Auto Scaling on one table and manage it on another with the same resource, so an autoscaled table is a different resource in the module (`aws_dynamodb_table.autoscaled`) from a table with fixed capacity (`aws_dynamodb_table.this`). The same goes for global secondary indexes. Decide when you create the table.

To change your mind later without replacing the table, add a `moved` block next to the module block in the same change. For a module block named `dynamodb_table`, turning autoscaling on:

```hcl
moved {
  from = module.dynamodb_table.aws_dynamodb_table.this[0]
  to   = module.dynamodb_table.aws_dynamodb_table.autoscaled[0]
}
```

and turning it off is the same block with `from` and `to` swapped. For an index named `GameTitleIndex`:

```hcl
moved {
  from = module.dynamodb_table.aws_dynamodb_global_secondary_index.this["GameTitleIndex"]
  to   = module.dynamodb_table.aws_dynamodb_global_secondary_index.autoscaled["GameTitleIndex"]
}
```

Check the plan: it should change the table or index in place, or not at all, and add or remove only `aws_appautoscaling_*` resources. Without the `moved` block, the plan replaces the table; deletion protection then makes the apply fail.

### Encryption

DynamoDB encrypts every table. `server_side_encryption` chooses the key: the AWS managed key `aws/dynamodb` by default, a customer managed key in `kms_key_arn`, or, with `enabled = false`, a key that AWS owns and that does not appear in your account. With a key in your account, each use is recorded in AWS CloudTrail, and with a customer managed key you also control who may use it.

### Replicas

`replicas` makes the table a global table, with a copy in each Region you list. The module requires on-demand billing for replicas. AWS also accepts provisioned capacity if it is autoscaled, but each replica's capacity and autoscaling would then have to be managed in its own Region, which the module does not do.

Replicas also need `stream_view_type`. When AWS adds a replica to a table without a stream, it turns one on, with `NEW_AND_OLD_IMAGES`, and the table no longer matches a configuration without one; setting `stream_view_type` keeps the two in step.

### Time to live

With `ttl` set, DynamoDB deletes items whose time in `ttl.attribute_name` has passed. Deletion is not immediate, and expired items can still be read until they are deleted; see [Time to Live](https://docs.aws.amazon.com/amazondynamodb/latest/developerguide/TTL.html) in the AWS documentation.

To turn TTL off once it has been on, set `ttl.enabled = false` and keep `attribute_name`. AWS needs the attribute's name to turn TTL off, so removing `ttl` instead fails at apply.

### Cost

On demand, you pay for each read and write, and for storage. With provisioned billing, you pay for the capacity units whether or not they are used. Point-in-time recovery is charged by the size of the table, replicas by their storage and the writes copied to them, and a customer managed key by the month. See [Amazon DynamoDB pricing](https://aws.amazon.com/dynamodb/pricing/).

## Contributing

Contributions are welcome, after review. Read [CONTRIBUTING.md](https://github.com/AutomateTheCloud/terraform-aws-dynamodb_table/blob/main/CONTRIBUTING.md) before opening a pull request, and report security problems as described in [SECURITY.md](https://github.com/AutomateTheCloud/terraform-aws-dynamodb_table/blob/main/SECURITY.md).

## Testing

The tests in `tests/` run offline against mocked AWS providers, so they need no AWS account:

```shell
terraform init
terraform test
```

## Reference

The sections below are generated from the code by [terraform-docs](https://terraform-docs.io). To update them, run `terraform-docs .`.

<!-- BEGIN_TF_DOCS -->
### Requirements

The following requirements are needed by this module:

- <a name="requirement_terraform"></a> [terraform](#requirement_terraform) (>= 1.9)

- <a name="requirement_aws"></a> [aws](#requirement_aws) (>= 6.44)

### Required Inputs

The following input variables are required:

#### <a name="input_details"></a> [details](#input_details)

Description: Names and tags shared by every resource in the module. `scope`, `purpose` and `environment` become the `Scope`, `Purpose` and `Environment` tags, and are converted to abbreviations that other modules can use in resource names (see the `metadata` output). [The `details` input](https://github.com/AutomateTheCloud/terraform-aws-dynamodb_table#the-details-input) explains why it is required.

- `scope` - (Required) What the resource belongs to, such as an organization or project: `Automate the Cloud`.
- `purpose` - (Required) What the resource is for: `Web Site`.
- `environment` - (Required) The environment: `Production`.
- `scope_abbr`, `purpose_abbr`, `environment_abbr` - (Optional) Abbreviations to use instead of the generated ones, which are lowercase with words joined by underscores (`Web Site` becomes `web_site`).
- `additional_tags` - (Optional) More tags for every resource, such as `{ CostCenter = "1234" }`.

Type:

```hcl
object({
    scope            = string
    scope_abbr       = optional(string)
    purpose          = string
    purpose_abbr     = optional(string)
    environment      = string
    environment_abbr = optional(string)
    additional_tags  = optional(map(string), {})
  })
```

#### <a name="input_hash_key"></a> [hash_key](#input_hash_key)

Description: The table's partition key, which every item must have: `{ name = "UserId", type = "S" }`. `type` is `S` (string), `N` (number) or `B` (binary). Changing it replaces the table.

Type:

```hcl
object({
    name = string
    type = string
  })
```

#### <a name="input_name"></a> [name](#input_name)

Description: The table's name, unique in the account and Region: 3 to 255 letters, numbers, underscores (_), hyphens (-) and periods (.). Changing it replaces the table.

Type: `string`

### Optional Inputs

The following input variables are optional (have default values):

#### <a name="input_autoscaling"></a> [autoscaling](#input_autoscaling)

Description: Turns on autoscaling of the table's read and write capacity. Requires `billing_mode = "PROVISIONED"`. The default, `null`, means fixed capacity, set by `read_capacity` and `write_capacity`.

Decide when you create the table. An autoscaled table is a different resource in the module, so that Terraform leaves its capacity to Application Auto Scaling. Turning autoscaling on or off later replaces the table unless you add a `moved` block to your configuration; see [Turning autoscaling on or off later](https://github.com/AutomateTheCloud/terraform-aws-dynamodb_table#turning-autoscaling-on-or-off-later).

- `read` - (Required) Settings for read capacity units.
- `write` - (Required) Settings for write capacity units.

Each takes:

- `min_capacity` - (Required) The fewest capacity units. The table is created with this many. At least 1.
- `max_capacity` - (Required) The most capacity units. At least `min_capacity`.
- `target_value` - (Optional) The percentage of the capacity that should be in use, from 20 to 90. Defaults to `70`.
- `scale_in_cooldown` - (Optional) Seconds to wait after a scale-in before the next one. Defaults to `0`.
- `scale_out_cooldown` - (Optional) Seconds to wait after a scale-out before the next one. Defaults to `0`.

Type:

```hcl
object({
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
```

Default: `null`

#### <a name="input_billing_mode"></a> [billing_mode](#input_billing_mode)

Description: How you pay for reads and writes:

- `PAY_PER_REQUEST` (default) - On demand: you pay for each request, and the table scales by itself.
- `PROVISIONED` - You set the read and write capacity units, in `read_capacity` and `write_capacity` or with `autoscaling`, and pay for them whether or not they are used.

You can change it later without replacing the table, but with global secondary indexes it takes extra steps; see [Changing the billing mode](https://github.com/AutomateTheCloud/terraform-aws-dynamodb_table#changing-the-billing-mode).

Type: `string`

Default: `"PAY_PER_REQUEST"`

#### <a name="input_deletion_protection_enabled"></a> [deletion_protection_enabled](#input_deletion_protection_enabled)

Description: Whether AWS refuses to delete the table and its replicas. Defaults to `true`, so a plan that would replace or destroy the table fails at apply, and the table keeps its items; its global secondary indexes are deleted before that, and applying the original configuration again rebuilds them. To delete the table, set it to `false` and apply first.

Type: `bool`

Default: `true`

#### <a name="input_global_secondary_indexes"></a> [global_secondary_indexes](#input_global_secondary_indexes)

Description: Global secondary indexes, keyed by index name. Each lets you query the table by other attributes than its own keys. You can add and remove them at any time. Defaults to none.

- `hash_key` - (Required) The index's partition key: `{ name = "GameTitle", type = "S" }`. `type` is `S` (string), `N` (number) or `B` (binary).
- `range_key` - (Optional) The index's sort key, in the same form. Defaults to none.
- `projection_type` - (Optional) Which attributes are copied into the index: `ALL` (default), `KEYS_ONLY`, or `INCLUDE` for the keys plus `non_key_attributes`.
- `non_key_attributes` - (Optional) With `INCLUDE` only, and required with it: the other attributes to copy into the index.
- `read_capacity`, `write_capacity` - (Optional) With `billing_mode = "PROVISIONED"` and no `autoscaling`, and required then: the index's capacity units. Leave them out for an on-demand table.
- `autoscaling` - (Optional) Autoscaling of the index's capacity, with `read` and `write` in the same form as the module's `autoscaling` input. Needs `billing_mode = "PROVISIONED"`. As for the table, decide when you create the index: turning it on or off later replaces the index unless you add a `moved` block.

An attribute used as a key by several indexes, or by the table and an index, must have the same type everywhere.

Type:

```hcl
map(object({
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
```

Default: `{}`

#### <a name="input_local_secondary_indexes"></a> [local_secondary_indexes](#input_local_secondary_indexes)

Description: Local secondary indexes, keyed by index name. Each sorts the items of one partition key by another attribute. The table needs a `range_key`, and AWS allows at most 5. Defaults to none.

AWS creates local secondary indexes only with the table: adding, changing or removing one replaces the table, and its data is lost. Use a global secondary index for anything you may add later.

- `range_key` - (Required) The index's sort key: `{ name = "Score", type = "N" }`. `type` is `S` (string), `N` (number) or `B` (binary).
- `projection_type` - (Optional) Which attributes are copied into the index: `ALL` (default), `KEYS_ONLY`, or `INCLUDE` for the keys plus `non_key_attributes`.
- `non_key_attributes` - (Optional) With `INCLUDE` only, and required with it: the other attributes to copy into the index.

Type:

```hcl
map(object({
    range_key = object({
      name = string
      type = string
    })
    projection_type    = optional(string, "ALL")
    non_key_attributes = optional(list(string), [])
  }))
```

Default: `{}`

#### <a name="input_point_in_time_recovery"></a> [point_in_time_recovery](#input_point_in_time_recovery)

Description: Continuous backups, from which the table can be restored to any second in the recovery period, to a new table. On by default. AWS charges for them by the size of the table.

- `enabled` - (Optional) Defaults to `true`.
- `recovery_period_in_days` - (Optional) How far back a restore can go, from 1 to 35 days. Defaults to AWS's default, 35. It applies to this table, not to its `replicas`, which keep 35 days.

Type:

```hcl
object({
    enabled                 = optional(bool, true)
    recovery_period_in_days = optional(number)
  })
```

Default: `{}`

#### <a name="input_range_key"></a> [range_key](#input_range_key)

Description: The table's sort key, in the same form as `hash_key`. Items with the same partition key are stored in its order. Defaults to none. Changing it replaces the table.

Type:

```hcl
object({
    name = string
    type = string
  })
```

Default: `null`

#### <a name="input_read_capacity"></a> [read_capacity](#input_read_capacity)

Description: The table's read capacity units, with `billing_mode = "PROVISIONED"` and no `autoscaling`, and required then. Leave it out for an on-demand table or with `autoscaling`.

Type: `number`

Default: `null`

#### <a name="input_region"></a> [region](#input_region)

Description: The AWS Region to create the table and its indexes in, such as `us-west-2`. Defaults to the Region of the AWS provider passed to the module.

Type: `string`

Default: `null`

#### <a name="input_replicas"></a> [replicas](#input_replicas)

Description: Copies of the table in other Regions, keyed by Region name, such as `us-west-2`. The table becomes a global table: each copy can be read and written, and DynamoDB keeps them in step. Defaults to none.

Replicas need `billing_mode = "PAY_PER_REQUEST"` and a `stream_view_type`: AWS turns a stream on when it adds a replica to a table without one, and the module keeps its configuration in step with that. With a customer managed key in `server_side_encryption`, every replica needs its own key, in its own Region.

- `kms_key_arn` - (Optional) The ARN of the customer managed key for this replica. Changing it replaces the replica.
- `point_in_time_recovery` - (Optional) Whether the replica has point-in-time recovery. Defaults to the table's `point_in_time_recovery.enabled`. A replica keeps AWS's 35-day recovery period: `point_in_time_recovery.recovery_period_in_days` applies to the table only.
- `deletion_protection_enabled` - (Optional) Defaults to the table's `deletion_protection_enabled`.
- `propagate_tags` - (Optional) Whether the replica gets the table's tags. Defaults to `true`.

Type:

```hcl
map(object({
    kms_key_arn                 = optional(string)
    point_in_time_recovery      = optional(bool)
    deletion_protection_enabled = optional(bool)
    propagate_tags              = optional(bool, true)
  }))
```

Default: `{}`

#### <a name="input_server_side_encryption"></a> [server_side_encryption](#input_server_side_encryption)

Description: The key the table is encrypted with. DynamoDB always encrypts tables; this chooses the key.

- `enabled` - (Optional) Defaults to `true`: the AWS managed key `aws/dynamodb` in your account, or the key in `kms_key_arn`. Each use of the key is recorded in AWS CloudTrail. `false` means a key that AWS owns and that does not appear in your account.
- `kms_key_arn` - (Optional) The ARN of a customer managed key, such as one created with the Automate the Cloud KMS key module. Needs `enabled = true`. Defaults to none.

Type:

```hcl
object({
    enabled     = optional(bool, true)
    kms_key_arn = optional(string)
  })
```

Default: `{}`

#### <a name="input_stream_view_type"></a> [stream_view_type](#input_stream_view_type)

Description: Turns on DynamoDB Streams, a log of every change to the table's items, and chooses what each record holds: `KEYS_ONLY`, `NEW_IMAGE`, `OLD_IMAGE` or `NEW_AND_OLD_IMAGES`. Defaults to `null`: no stream.

Type: `string`

Default: `null`

#### <a name="input_table_class"></a> [table_class](#input_table_class)

Description: The storage class: `STANDARD` (default), or `STANDARD_INFREQUENT_ACCESS` for a table that stores much and is read little, with cheaper storage and dearer reads and writes. You can change it later, in place.

Type: `string`

Default: `"STANDARD"`

#### <a name="input_timeouts"></a> [timeouts](#input_timeouts)

Description: How long Terraform waits for the table, and for each global secondary index, to be created, updated or deleted, such as `"2h"`. Building an index on a large table can take hours. Each defaults to the AWS provider's default.

- `create` - (Optional)
- `update` - (Optional)
- `delete` - (Optional)

Type:

```hcl
object({
    create = optional(string)
    update = optional(string)
    delete = optional(string)
  })
```

Default: `{}`

#### <a name="input_ttl"></a> [ttl](#input_ttl)

Description: Turns on time to live (TTL): DynamoDB deletes each item some time after the moment stored in `attribute_name`, a number of seconds since 1970 (Unix epoch time). Items without the attribute are kept. Defaults to `null`: TTL off.

- `attribute_name` - (Required) The attribute that holds each item's expiry time.
- `enabled` - (Optional) Defaults to `true`. To turn TTL off once it has been on, set `enabled = false` and keep `attribute_name`: AWS needs the attribute's name to turn TTL off, so setting `ttl` back to `null` fails.

Type:

```hcl
object({
    attribute_name = string
    enabled        = optional(bool, true)
  })
```

Default: `null`

#### <a name="input_write_capacity"></a> [write_capacity](#input_write_capacity)

Description: The table's write capacity units, with `billing_mode = "PROVISIONED"` and no `autoscaling`, and required then. Leave it out for an on-demand table or with `autoscaling`.

Type: `number`

Default: `null`

### Outputs

The following outputs are exported:

#### <a name="output_metadata"></a> [metadata](#output_metadata)

Description: Everything the module created, in one object, so that other configurations need only one reference:

- `details` - The scope, purpose and environment, each with its `name`, `abbr` (lowercase, words joined by underscores) and `machine` (lowercase letters and numbers only) forms, and the `tags` applied to every resource.
- `aws` - The `account.id`, and the `region` `name`, `abbr` (such as `use1` for `us-east-1`) and `description`.
- `dynamodb_table` - The table's `name` (also its `id`), `arn`, `hash_key`, `range_key`, `billing_mode`, `stream_arn` and `stream_label` (when `stream_view_type` is set), `replica` (each with its `region_name`, `arn` and `stream_arn`), `tags` and the rest of its attributes. `read_capacity` and `write_capacity` are `null` when `autoscaling` sets them; see `appautoscaling_target`.
- `dynamodb_global_secondary_index` - The global secondary indexes, keyed like `global_secondary_indexes`, each with its `index_name`, `arn`, `key_schema`, `projection` and `provisioned_throughput` (`null` for an autoscaled index), or `null` when there are none.
- `appautoscaling_target` - The Application Auto Scaling targets, keyed `table/read`, `table/write`, `index/<index name>/read` and `index/<index name>/write`, each with its `resource_id`, `scalable_dimension`, `min_capacity`, `max_capacity` and the rest of its attributes, or `null` when nothing is autoscaled.
- `appautoscaling_policy` - The target tracking policies, keyed like `appautoscaling_target`, each with its `name`, `arn` and `target_tracking_scaling_policy_configuration`, or `null` when nothing is autoscaled.
<!-- END_TF_DOCS -->

## License

This module is licensed under the [Apache License 2.0](https://github.com/AutomateTheCloud/terraform-aws-dynamodb_table/blob/main/LICENSE). See [NOTICE](https://github.com/AutomateTheCloud/terraform-aws-dynamodb_table/blob/main/NOTICE) for the copyright notice.

The Automate the Cloud name and logo are not covered by this license.

---

Maintained by [Automate the Cloud](https://automatethe.cloud), a Kentucky 501(c)(3) that teaches cloud infrastructure and helps nonprofits run theirs.
