# Changelog

All notable changes to this module are listed here. The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and the module uses [semantic versioning](https://semver.org/): a new major version means callers must change their code.

## [Unreleased]

## [1.0.0] - 2026-10-05

Initial release.

### Added

- An Amazon DynamoDB table with secure defaults: billed on demand, encrypted with the AWS managed key, point-in-time recovery on, and deletion protection on.
- Partition and sort keys, with the attribute definitions built from them, and up to 5 local secondary indexes.
- Global secondary indexes as separate resources, which can be added and removed without touching the table.
- Provisioned capacity, fixed or autoscaled with Application Auto Scaling target tracking, for the table and for each global secondary index, with Terraform leaving autoscaled capacity alone.
- DynamoDB Streams, time to live, the table class, and the point-in-time recovery period.
- Replicas in other Regions (global tables), each with its own customer managed key if the table has one.
- Encryption with the AWS managed key, a customer managed key, or an AWS owned key.
- `region`, to create the table in a Region other than the provider's.
- Checks at plan time for values AWS would reject.
- A `metadata` output with everything the module created.
- Offline tests, and examples for a basic table, indexes with a stream and a customer managed key, autoscaling, and a global table.

[Unreleased]: https://github.com/AutomateTheCloud/terraform-aws-dynamodb_table/compare/v1.0.0...HEAD
[1.0.0]: https://github.com/AutomateTheCloud/terraform-aws-dynamodb_table/releases/tag/v1.0.0
