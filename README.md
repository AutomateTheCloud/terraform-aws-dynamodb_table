# AWS - DynamoDB - Table - Terraform Module
Terraform module to create DynamoDB Tables (AutomateTheCloud model)

***

## Usage
```hcl
module "dynamodb_table" {
  source    = "../"
  providers = { aws.this = aws.example }

  details = {
    scope               = "DynamoDB"
    purpose             = "Table - example"
    environment         = "dev"
    additional_tags = {
      "Project"         = "Project Name"
      "ProjectID"       = "123456789"
      "Contact"         = "David Singer - david.singer@example.com"
    }
  }

  name           = "demo-example"
  billing_mode   = "PROVISIONED"
  read_capacity  = 5
  write_capacity = 5

  server_side_encryption = {
    enabled     = true
    kms_key_arn = null
  }

  stream = {
    enabled   = false
    view_type = ""
  }

  hash_key  = "id"
  range_key = "title"
  attributes = [
    {
      name = "id"
      type = "N"
    },
    {
      name = "title"
      type = "S"
    },
    {
      name = "age"
      type = "N"
    }
  ]

  global_secondary_indexes = [
    {
      name               = "TitleIndex"
      hash_key           = "title"
      range_key          = "age"
      projection_type    = "INCLUDE"
      read_capacity      = 10
      write_capacity     = 10
      non_key_attributes = ["id"]
    }
  ]

  ttl = {
    enabled        = false
    attribute_name = ""
  }

  autoscaling = {
    enabled = true
    defaults = {
      scale_in_cooldown  = 0
      scale_out_cooldown = 0
      target_value       = 70
    }
    read = {
      scale_in_cooldown  = 50
      scale_out_cooldown = 40
      target_value       = 45
      max_capacity       = 10
    }
    write = {
      scale_in_cooldown  = 50
      scale_out_cooldown = 40
      target_value       = 45
      max_capacity       = 10
    }
    indexes = {
      TitleIndex = {
        read_max_capacity  = 30
        read_min_capacity  = 10
        write_max_capacity = 30
        write_min_capacity = 10
      }
    }
  }
}
```

***

## Inputs
| Name | Description | Type | Default |
|------|-------------|:----:|:-------:|
| `attributes` | Attributes (Name: The name of the attribute, Type: (S)tring, (N)umber, (B)inary data) | `list(object({name, type})` | `[]` |
| `autoscaling` | Autoscaling Details | `object({enabled, defaults, read, write, indexes})` | `[]` |
| `billing_mode` | Billing Mode (PROVISIONED, PAY_PER_REQUEST) | `string` | `PAY_PER_REQUEST` |
| `global_secondary_indexes` | Global Secondary Indexes | `list(object({name, hash_key, range_key, projection_type, read_capacity, write_capacity, non_key_attributes}))` | `[]` |
| `hash_key` | The attribute to use as the hash (partition) key. Must also be defined as an attribute | `string` | |
| `local_secondary_indexes` | Local Secondary Indexes | `list(object({name, range_key, read_capacity, write_capacity, non_key_attributes}))` | `[]` |
| `name` | Name of the DynamoDB table | `string` | |
| `point_in_time_recovery_enabled` | Whether to enable point-in-time recovery | `bool` | `false` |
| `range_key` | The attribute to use as the range (sort) key | `string` | |
| `read_capacity` | The number of read units for this table. If the billing_mode is PROVISIONED, this field should be greater than 0 | `number` | |
| `replica_regions` | Region names for creating replicas for a global DynamoDB table | `list(string)` | `[]` |
| `server_side_encryption` | Server Side Encryption Details | `object({enabled, kms_key_arn})` | `{enabled = true, kms_key_arn = null}` |
| `stream` | Stream Details (Valid View Types: KEYS_ONLY, NEW_IMAGE, OLD_IMAGE, NEW_AND_OLD_IMAGES) | `object({enabled, view_type})` | `{enabled = false, view_type = ""}` |
| `timeouts` | List of timeout values per action (`create`, `update` and `delete`) | `object({create, update, delete})` | `{create = "10m", update = "60m", delete = "10m"}` |
| `ttl` | TTL Details (Attribute Name: The name of the table attribute to store the TTL timestamp in) | `object({enabled, attribute_name})` | `{enabled = false, view_type = ""}` |
| `write_capacity` | The number of write units for this table. If the billing_mode is PROVISIONED, this field should be greater than 0 | `number` | |

## Inputs (Details)
| Name | Description | Type | Default |
|------|-------------|:----:|:-------:|
| `details.scope` | (Required) Scope Name - What does this object belong to? (Organization Name, Project, etc) | `string` | |
| `details.scope_abbr` | (Optional) Scope [Abbreviation](#Abbreviations) Override | `string` | |
| `details.purpose` | (Required) Purpose Name - What is the purpose or function of this object, or what does this object server? | `string` | |
| `details.purpose_abbr` | (Optional) Purpose [Abbreviation](#Abbreviations) Override | `string` | |
| `details.environment` | (Required) Environment Name | `string` | |
| `details.environment_abbr` | (Optional) Environment [Abbreviation](#Abbreviations) Override | `string` | |
| `details.additional_tags` | (Optional) [Additional Tags](#Additional-Tags) for resources | `map` | `[]` |

***

## Outputs
All outputs from this module are mapped to a single output named `metadata` to make it easier to capture all of the relevant metadata that would be useful when referenced by other stacks (requires only a single output reference in your code, instead of dozens!)

| Name | Description |
|:-----|:------------|
| `details.scope.name` | Scope name |
| `details.scope.abbr` | Scope abbreviation |
| `details.scope.machine` | Scope machine-friendly abbreviation |
| `details.purpose.name` | Purpose name |
| `details.purpose.abbr` | Purpose abbreviation |
| `details.purpose.machine` | Purpose machine-friendly abbreviation |
| `details.environment.name` | Environment name |
| `details.environment.abbr` | Environment abbreviation |
| `details.environment.machine` | Environment machine-friendly abbreviation |
| `details.tags` | Map of tags applied to all resources |
| `aws.account.id` | AWS Account ID |
| `aws.region.name` | AWS Region name, example: `us-east-1` |
| `aws.region.abbr` | AWS Region four letter abbreviation, example: `use1` |
| `aws.region.description` | AWS Region description, example: `US East (N. Virginia)` |
| `dynamodb.table` | DynamoDB - Table |

***

## Notes

### Abbreviations
* When generating resource names, the module converts each identifier to a more 'machine-friendly' abbreviated format, removing all special characters, replacing spaces with underscores (_), and converting to lowercase. Example: 'Demo - Module' => 'demo_module'
* Not all resource names allow underscores. When those are encountered, the detail identifier will have the underscore removed (test_example => testexample) automatically. This machine-friendly abbreviation is referred to as 'machine' within the module.
* The abbreviations can be overridden by suppling the abbreviated names (ie: scope_abbr). This is useful when you have a long name and need the created resource names to be shorter. Some resources in AWS have shorter name constraints than others, or you may just prefer it shorter. NOTE: If specifying the Abbreviation, be sure to follow the convention of no spaces and no special characters (except for underscore), otherwise resoure creation may fail.

### Additional Tags
* You can specify additional tags for resources by adding to the `details.additional_tags` map.
```
additional_tags = {
  "Example"         = "Extra Tag"
  "Project"         = "Project Name"
  "CostCenter"      = "123456"
}
```

***

## Terraform Versions
Terraform ~> 1.11.0 is supported.

## Provider Versions
| Name | Version |
|------|---------|
| aws | `~> 5.93` |

