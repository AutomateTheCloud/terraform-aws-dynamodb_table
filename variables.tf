variable "attributes" {
  description = "Attributes (Name: The name of the attribute, Type: (S)tring, (N)umber, (B)inary data)"
  type = list(object({
    name = string
    type = string
  }))
  default = []
}

variable "autoscaling" {
  description = "Autoscaling Details"
  type = object({
    enabled  = bool
    defaults = map(string)
    read     = map(string)
    write    = map(string)
    indexes  = map(map(string))
  })
  default = {
    enabled = false
    defaults = {
      scale_in_cooldown  = 0
      scale_out_cooldown = 0
      target_value       = 70
    }
    read    = {}
    write   = {}
    indexes = {}
  }
}

variable "billing_mode" {
  description = "Billing Mode (PROVISIONED, PAY_PER_REQUEST)"
  type        = string
  default     = "PAY_PER_REQUEST"
}

variable "global_secondary_indexes" {
  description = "Global Secondary Indexes"
  type = list(object({
    name               = string
    hash_key           = string
    range_key          = string
    projection_type    = string
    read_capacity      = string
    write_capacity     = string
    non_key_attributes = list(string)
  }))
  default = []
}

variable "hash_key" {
  description = "The attribute to use as the hash (partition) key. Must also be defined as an attribute"
  type        = string
  default     = null
}

variable "local_secondary_indexes" {
  description = "Local Secondary Indexes"
  type = list(object({
    name               = string
    range_key          = string
    projection_type    = string
    non_key_attributes = list(string)
  }))
  default = []
}

variable "name" {
  description = "Name of the DynamoDB table"
  type        = string
  default     = ""
}

variable "point_in_time_recovery_enabled" {
  description = "Whether to enable point-in-time recovery"
  type        = bool
  default     = false
}

variable "range_key" {
  description = "The attribute to use as the range (sort) key"
  type        = string
  default     = null
}

variable "read_capacity" {
  description = "The number of read units for this table. If the billing_mode is PROVISIONED, this field should be greater than 0"
  type        = number
  default     = null
}

variable "replica_regions" {
  description = "Region names for creating replicas for a global DynamoDB table"
  type        = list(string)
  default     = []
}

variable "server_side_encryption" {
  description = "Server Side Encryption Details"
  type = object({
    enabled     = bool
    kms_key_arn = string
  })
  default = {
    enabled     = true
    kms_key_arn = null
  }
}

variable "stream" {
  description = "Stream Details (Valid View Types: KEYS_ONLY, NEW_IMAGE, OLD_IMAGE, NEW_AND_OLD_IMAGES)"
  type = object({
    enabled   = bool
    view_type = string
  })
  default = {
    enabled   = false
    view_type = ""
  }
}

variable "timeouts" {
  description = "List of timeout values per action (`create`, `update` and `delete`)"
  type = object({
    create = string
    update = string
    delete = string
  })
  default = {
    create = "10m"
    update = "60m"
    delete = "10m"
  }
}

variable "ttl" {
  description = "TTL Details (Attribute Name: The name of the table attribute to store the TTL timestamp in)"
  type = object({
    enabled        = bool
    attribute_name = string
  })
  default = {
    enabled        = false
    attribute_name = ""
  }
}

variable "write_capacity" {
  description = "The number of write units for this table. If the billing_mode is PROVISIONED, this field should be greater than 0"
  type        = number
  default     = null
}
