variable "apex_domain" {
  default = ""
}
variable "key_name" {
  default = ""
}

data "aws_availability_zones" "allzones" {}