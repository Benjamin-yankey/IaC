variable "vpc_id" { type = string }
variable "my_ip" { type = string }
variable "security_group_name" { 
    type = string
    default = "web-sg" 
    }
