# Basic table

An on-demand DynamoDB table named `example-basic`, with the partition key `UserId` and the sort key `GameTitle`, both strings. Everything else is the module's default: the table is encrypted with the AWS managed key `aws/dynamodb`, point-in-time recovery keeps 35 days of continuous backups, and deletion protection is on.

## Run it

```shell
terraform init
terraform apply
```

To choose another name, add `-var 'name=<table name>'`. Table names must be unique in the account and Region.

## Remove it

Deletion protection is on, as it is by default, so AWS refuses to delete the table. To remove everything, turn it off first, then destroy:

```shell
terraform apply -var deletion_protection_enabled=false
terraform destroy -var deletion_protection_enabled=false
```

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

Default: `"example-basic"`

### Outputs

The following outputs are exported:

#### <a name="output_dynamodb_table"></a> [dynamodb_table](#output_dynamodb_table)

Description: Name and ARN of the table
<!-- END_TF_DOCS -->