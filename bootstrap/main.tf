resource "awscc_s3_bucket" "bootstrap_bucket" {
  bucket_name = "dmac-bootstrap-tfstate"

  # Avoid Public Access by mistake
  public_access_block_configuration = {
    block_public_acls       = true
    block_public_policy     = true
    ignore_public_acls      = true
    restrict_public_buckets = true
  }

  # Versioning
  versioning_configuration = {
    status = "Enabled"
  }

  # Encryption Defaults: AES-256 - Server-side encryption with S3 managed keys (SSE-S3) 
  # https://docs.aws.amazon.com/AmazonS3/latest/userguide/default-encryption-faq.html
  bucket_encryption = {
    server_side_encryption_configuration = [{
      server_side_encryption_by_default = {
        sse_algorithm = "AES256"
      }
    }]
  }


}