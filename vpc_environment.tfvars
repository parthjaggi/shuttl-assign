vpc = {
    tag                   = "SHUTTL"
    cidr_block            = "10.0.0.0/16"
    subnet_size           = 4096
}
launch_config = {
    instance_type         = "t2.micro"
    startup_file_path     = "./scripts/startup_app.sh"
}
autoscaling_config = {
    min_size                                 = 1
    desired_capacity                         = 2
    max_size                                 = 4
    on_demand_base_capacity                  = 1
    on_demand_percentage_above_base_capacity = 0
    spot_instance_pools                      = 2
}