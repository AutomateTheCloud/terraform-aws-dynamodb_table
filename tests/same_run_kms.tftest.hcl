# Copyright 2026 Automate the Cloud Inc.
# SPDX-License-Identifier: Apache-2.0

# Keys created in the same run, whose ARNs are unknown at plan time, still plan: nothing
# the module counts or loops over depends on them.

mock_provider "aws" {
  mock_data "aws_region" {
    defaults = {
      region      = "us-east-1"
      description = "US East (N. Virginia)"
    }
  }

  mock_data "aws_caller_identity" {
    defaults = {
      account_id = "123456789012"
    }
  }

  mock_resource "aws_kms_key" {
    defaults = {
      arn = "arn:aws:kms:us-east-1:123456789012:key/1111aaaa-11aa-11aa-11aa-1111aaaa1111"
    }
  }
}

mock_provider "aws" {
  alias = "us_west_2"

  mock_resource "aws_kms_key" {
    defaults = {
      arn = "arn:aws:kms:us-west-2:123456789012:key/2222bbbb-22bb-22bb-22bb-2222bbbb2222"
    }
  }
}

run "same_run_keys" {
  command = plan

  module {
    source = "./tests/fixtures/same_run_kms"
  }

  assert {
    condition     = length(module.table.metadata.details.tags) == 3
    error_message = "The module must plan with keys created in the same run."
  }
}

run "same_run_keys_apply" {
  command = apply

  module {
    source = "./tests/fixtures/same_run_kms"
  }

  assert {
    condition     = output.metadata.dynamodb_table.name == "same-run" && length(output.metadata.dynamodb_table.replica) == 1
    error_message = "The table and its replica must be created with the same-run keys."
  }
}
