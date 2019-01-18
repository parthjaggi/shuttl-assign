# shuttl-assign

To Run Packer:
`packer validate packer.json`
`packer build packer.json`

To Run Terraform:
`terraform plan -var-file credentials.tfvars  -var-file main.tfvars  -var-file vpc_environment.tfvars`
`terraform apply -var-file credentials.tfvars  -var-file main.tfvars  -var-file vpc_environment.tfvars`