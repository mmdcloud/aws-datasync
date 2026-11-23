
output "id" {
  description = "ID of the instance"
  value       = aws_instance.instance.id
}

output "public_ip" {
  value = aws_instance.instance.public_ip
}
