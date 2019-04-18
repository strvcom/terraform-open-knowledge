resource "aws_s3_bucket" "test" {
  bucket = "${terraform.workspace}-olalala"

  versioning {
    enabled = true
  }
}
