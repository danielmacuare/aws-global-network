resource "tls_private_key" "this" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "null_resource" "create_ssh_dir" {
  provisioner "local-exec" {
    command     = "mkdir -p ${var.project_root}/ssh-keys"
    interpreter = ["/bin/sh", "-c"]
  }
}

resource "local_file" "private_key" {
  depends_on = [null_resource.create_ssh_dir]

  content         = tls_private_key.this.private_key_pem
  filename        = "${var.project_root}/ssh-keys/${var.region_short}-${var.environment}.pem"
  file_permission = "0400"
}

# Terraform handles idempotency
resource "aws_key_pair" "this" {
  key_name   = "kp-${var.region_short}-${var.environment}"
  public_key = tls_private_key.this.public_key_openssh

  tags = merge(
    var.default_tags,
    {
      Name = "kp-${var.region_short}-${var.environment}"
    }
  )
}
