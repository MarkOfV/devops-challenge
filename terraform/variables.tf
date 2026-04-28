variable "my_ip" {
  type        = string
  description = "My IP address e.g. 1.2.3.4/32. Get from http://checkip.amazonaws.com/"
  
  validation {
    condition     = can(regex("^(\\d{1,3})\\.(\\d{1,3})\\.(\\d{1,3})\\.(\\d{1,3})/32$", var.my_ip))
    error_message = "The my_ip value must be a valid IPv4 address with a /32 mask."
  }
}

variable "stack_name" {
  type    = string
  default = "NextWorkCodeDeployEC2Stack"
}

variable "region" {
  type    = string
  default = "eu-west-1" 
}
