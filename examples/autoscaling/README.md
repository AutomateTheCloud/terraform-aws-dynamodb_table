# Autoscaling

A table with provisioned capacity, which Application Auto Scaling adjusts to the load. It keeps about 70 percent of the capacity in use: reads between 2 and 20 capacity units, writes between 1 and 10. The global secondary index `GameTitleIndex` scales the same way, with a target of 50 percent for reads.

The table and the index are created at their minimum capacity. Terraform does not change their capacity afterward; Application Auto Scaling does.

## Run it

```shell
terraform init
terraform apply
```

The `autoscaling` output lists each scaled dimension with its minimum and maximum.

If this is the first autoscaled DynamoDB table in the account, Application Auto Scaling creates the service-linked role `AWSServiceRoleForApplicationAutoScaling_DynamoDBTable`. It stays after `terraform destroy`.

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

Default: `"example-autoscaling"`

### Outputs

The following outputs are exported:

#### <a name="output_autoscaling"></a> [autoscaling](#output_autoscaling)

Description: Minimum and maximum capacity of each autoscaled table and index dimension
<!-- END_TF_DOCS -->