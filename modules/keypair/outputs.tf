output "key_name" {
  description = "Key pair name"
  value       = aws_key_pair.this.key_name
}

output "private_key_path" {
  description = "Private key file path"
  value       = var.private_key_path
}
