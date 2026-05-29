output "k3s_node_public_ip" {
  description = "Public IP of the managed node: WordPress will be accessible here"
  value       = aws_instance.k3s.public_ip
}
