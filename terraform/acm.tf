# Generate a private key for self-signed certificate
resource "tls_private_key" "main" {
  algorithm = "RSA"
  rsa_bits  = 2048
}

# Generate self-signed certificate
resource "tls_self_signed_cert" "main" {
  private_key_pem = tls_private_key.main.private_key_pem

  subject {
    common_name  = "petclinic.local"
    organization = "ISI Dakar"
  }

  validity_period_hours = 8760 # 1 year

  allowed_uses = [
    "key_encipherment",
    "digital_signature",
    "server_auth",
  ]

  dns_names = [
    "localhost",
    "petclinic.local",
    "*.elb.amazonaws.com" # Wildcard to cover ALB generated DNS names
  ]
}

# Import self-signed certificate into AWS Certificate Manager (ACM)
resource "aws_acm_certificate" "cert" {
  private_key      = tls_private_key.main.private_key_pem
  certificate_body = tls_self_signed_cert.main.cert_pem

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-self-signed-cert"
  })
}
