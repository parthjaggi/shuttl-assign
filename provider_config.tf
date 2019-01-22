variable "provider" {
  type = "map"
  default = {
    access_key = ""
    secret_key = ""
    region     = ""
  }
}

provider "aws" {
  access_key = "${var.provider["access_key"]}"
  secret_key = "${var.provider["secret_key"]}"
  region     = "${var.provider["region"]}"

  # assume_role {
  #   role_arn = "arn:aws:iam::1234567890:role/TerraformRuntimeRole"
  # }
}