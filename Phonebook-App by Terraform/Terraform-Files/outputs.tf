output "website" {
  value = "http://${aws_route53_record.phonebook-route53.name}"
}

output "alb-dns-address" {
  value = "http://${aws_alb.phonebook-alb.dns_name}"
}

output "rds-address" {
  value = aws_db_instance.phonebook-rds.address

}

output "rds-endpoint" {
  value = aws_db_instance.phonebook-rds.endpoint

}
