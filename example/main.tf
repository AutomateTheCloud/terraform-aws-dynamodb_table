terraform {
  required_version = "~> 1.11.0"
}

##-----------------------------------------------------------------------------
# Providers
provider "aws" {
  alias  = "example"
  region = "us-east-1"
}

##-----------------------------------------------------------------------------
# Module: DynamoDB - Table
module "dynamodb_table" {
  source    = "../"
  providers = { aws.this = aws.example }

  details = {
    scope               = "Demo"
    purpose             = "DynamoDB Table"
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

##-----------------------------------------------------------------------------
# Outputs
output "metadata" {
  description = "Metadata"
  value = module.dynamodb_table.metadata
}
