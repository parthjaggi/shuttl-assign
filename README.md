# shuttl-assign

To Run Packer:
`packer validate -var-file=credentials.json packer.json`
`packer build -var-file=credentials.json packer.json`

To Run Terraform:
`terraform plan -var-file credentials.tfvars  -var-file main.tfvars  -var-file vpc_environment.tfvars`
`terraform apply -var-file credentials.tfvars  -var-file main.tfvars  -var-file vpc_environment.tfvars`