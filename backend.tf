terraform {
  required_version = ">= 1.5.0"

  backend "s3" {
    bucket       = "projectiacterraformstatebucket"
    key          = "foundation/terraform.tfstate"
    region       = "eu-west-1"
    use_lockfile = true
    encrypt      = true
  }
}
