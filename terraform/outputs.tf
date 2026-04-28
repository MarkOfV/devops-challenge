output "url" {
  value = "http://${aws_instance.web_server.public_ip}"
  description = "production web server URL"
}

output "vpc_id" {
  value = aws_vpc.main.id
}