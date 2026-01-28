provider "aws" {
  region = var.aws_region
}
module "vpc" {
  source            = "./modules/vpc"
  availability_zone = var.availability_zone
}
module "security" {
  source = "./modules/security"
  vpc_id = module.vpc.vpc_id
  my_ip  = var.my_ip
}

module "keypair" {
  source = "./modules/keypair"

  key_name         = "project-iac-with-terraform-keypair"
  private_key_path = "${path.module}/project-iac-with-terraform-keypair.pem"
}

module "ec2" {
  source             = "./modules/ec2"
  ami_id             = var.ami_id
  subnet_id          = module.vpc.public_subnet_id
  security_group_ids = [module.security.security_group_id]
  key_name = module.keypair.key_name

}

