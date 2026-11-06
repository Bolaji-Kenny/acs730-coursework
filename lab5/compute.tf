data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = var.ami_owners

  filter {
    name   = "name"
    values = [var.ami_name_filter]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

resource "aws_instance" "web" {
  ami                         = data.aws_ami.amazon_linux.id
  instance_type               = var.instance_type
  subnet_id                   = aws_subnet.public[var.web_subnet_key].id
  vpc_security_group_ids      = [aws_security_group.web.id]
  associate_public_ip_address = true

  user_data = <<-EOT
    #!/bin/bash
    dnf install -y httpd
    echo "<h1>ACS730 Lab 5 - ${local.name_prefix}</h1>" > /var/www/html/index.html
    systemctl enable --now httpd
  EOT

  user_data_replace_on_change = true

  # The instance only becomes reachable from the internet once the route to the
  # internet gateway exists. Nothing in the instance's arguments references the
  # route or its association, so the implicit graph does not order them.
  depends_on = [
    aws_internet_gateway.main,
    aws_route_table_association.public,
  ]

  tags = { Name = "${local.name_prefix}-web" }
}
