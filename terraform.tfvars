vpc = {
    tag                   = "SHUTTL"
    cidr_block            = "10.0.0.0/16"
    subnet_size           = 4096
}
apex_domain               = "shuttl.com"
key_name                  = "practice"
launch_config = {
    instance_type         = "t2.micro"
}
autoscaling_config = {
    min_size              = 1
    desired_capacity      = 2
    max_size              = 4
}