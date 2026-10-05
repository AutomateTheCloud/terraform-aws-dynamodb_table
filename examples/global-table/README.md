# Global table

A DynamoDB global table: the table in us-east-1 and a replica in us-west-2. Both can be read and written, and DynamoDB copies each change to the other Region.

Replicas need an on-demand table, the module's default, and a stream, which the example turns on with new and old images. Each replica is encrypted with the AWS managed key `aws/dynamodb` in its own Region, gets the table's tags, and has point-in-time recovery and deletion protection like the table.

## Run it

```shell
terraform init
terraform apply
```

Adding the replica takes several minutes. You pay for storage and writes in each Region.

## Remove it

Deletion protection is on, as it is by default, so AWS refuses to delete the table. To remove everything, turn it off first, then destroy:

```shell
terraform apply -var deletion_protection_enabled=false
terraform destroy -var deletion_protection_enabled=false
```

Deletion protection applies to the replica too, so the first command turns it off on both.

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

Default: `"example-global-table"`

### Outputs

The following outputs are exported:

#### <a name="output_dynamodb_table"></a> [dynamodb_table](#output_dynamodb_table)

Description: ARN of the table and of each replica
<!-- END_TF_DOCS -->