# Complete

A table of game scores, with the options most applications use:

- The partition key `UserId` and the sort key `GameTitle`.
- A local secondary index, `TopScoreIndex`, which sorts each player's games by `TopScore`.
- Two global secondary indexes: `GameTitleIndex` finds the best players of a game, and copies their `Wins` and `Losses` into the index; `LossesIndex` holds only the keys of the items with a `Losses` attribute.
- A stream of every change, with each item before and after the change (`NEW_AND_OLD_IMAGES`).
- Time to live on the `ExpiresAt` attribute.
- Point-in-time recovery for 14 days instead of 35.
- Encryption with a customer managed key that the example creates, and an extra `CostCenter` tag.

## Run it

```shell
terraform init
terraform apply -parallelism=1
```

`-parallelism=1` makes Terraform create the two global secondary indexes one after the other: DynamoDB builds one index at a time per table, and rejects a second one started at the same moment. Each index takes several minutes after the table exists.

## Remove it

Deletion protection is on, as it is by default, so AWS refuses to delete the table. To remove everything, turn it off first, then destroy:

```shell
terraform apply -var deletion_protection_enabled=false
terraform destroy -parallelism=1 -var deletion_protection_enabled=false
```

`-parallelism=1` deletes the two global secondary indexes one after the other, for the same reason as when they are created.

AWS deletes the customer managed key 7 days after `terraform destroy`. Until then, `aws kms cancel-key-deletion` brings it back.

<!-- BEGIN_TF_DOCS -->
### Requirements

The following requirements are needed by this module:

- <a name="requirement_terraform"></a> [terraform](#requirement_terraform) (>= 1.9)

- <a name="requirement_aws"></a> [aws](#requirement_aws) (~> 6.44)

### Optional Inputs

The following input variables are optional (have default values):

#### <a name="input_deletion_protection_enabled"></a> [deletion_protection_enabled](#input_deletion_protection_enabled)

Description: Whether AWS refuses to delete the table. Set it to false and apply before terraform destroy.

Type: `bool`

Default: `true`

#### <a name="input_name"></a> [name](#input_name)

Description: Name of the table, unique in the account and Region

Type: `string`

Default: `"example-complete"`

### Outputs

The following outputs are exported:

#### <a name="output_dynamodb_table"></a> [dynamodb_table](#output_dynamodb_table)

Description: Name, ARN and stream ARN of the table, and the ARNs of its global secondary indexes
<!-- END_TF_DOCS -->