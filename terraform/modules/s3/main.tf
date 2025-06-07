# Create an S3 bucket as source
resource "aws_s3_bucket" "source_bucket" {
  bucket = var.bucket_name
  tags = {
    Name = var.bucket_name
  }
}