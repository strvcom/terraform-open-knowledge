/*
 * This file defines everything needed to host a static content on S3 + CloudFront combo.
 */

# Let's define an S3 bucket which will hold our static content.
resource "aws_s3_bucket" "content" {
  bucket = "${var.project}-${terraform.workspace}"

  # Ideally only the CloudFront distribution would have access to this bucket, but for this demo
  # setting that up would be too complex. Look at CloudFront Origin Access Identity to learn how to
  # set up proper permissions for the bucket:
  # https://www.terraform.io/docs/providers/aws/r/cloudfront_origin_access_identity.html
  acl = "public-read"

  # Allow terraform to destroy this bucket in case there is some content in it. We can recreate the
  # content any time by re-building the site.
  force_destroy = true

  # This is a cost optimisation. Since we use CloudFront as a cache layer, we do not expect S3 to
  # get many read requests nor do we need the extra redundancy of S3 since we can easily recreate
  # all the content. We can move all files stored in this bucket to a cheaper S3 storage variant
  # after 30 days. Ideally we would do that after 0 days but alas, that is not possible for this
  # storage class. 🤷‍♂️
  lifecycle_rule {
    id      = "default-storage-class"
    enabled = true

    transition {
      days          = 30
      storage_class = "ONEZONE_IA"
    }
  }

  website {
    index_document = "index.html"
  }
}

# And now create the CloudFront distribution which will serve our content to the clients.
resource "aws_cloudfront_distribution" "content" {
  # By default, Terraform will wait until AWS replicates the distribution across its delivery
  # network which might take more than 30 minutes. We do not need to wait for that, we only need the
  # distribution to exist in order to continue.
  wait_for_deployment = false

  enabled             = true
  price_class         = "PriceClass_100"
  default_root_object = "index.html"

  # To associate a custom domain with this distribution, you would add the domain names (aliases)
  # here.
  aliases = []

  # The origin block tells CloudFront where to fetch the actual content if it does not have it in
  # its cache. Here we use a custom origin config which uses good old HTTP requests to a specified
  # domain (the bucket's regional address). You can also use an S3 origin but this requires setting
  # up CloudFront Origin Access Identity.
  #
  # Note that if the bucket's name contains dots you will have to use `http-only` in
  # `origin_protocol_policy` because the S3 TLS certificate will be invalid for the regional domain
  # name.
  origin {
    origin_id   = "${aws_s3_bucket.content.bucket_regional_domain_name}"
    domain_name = "${aws_s3_bucket.content.bucket_regional_domain_name}"

    custom_origin_config {
      http_port                = "80"
      https_port               = "443"
      origin_keepalive_timeout = "30"
      origin_read_timeout      = "30"
      origin_protocol_policy   = "http-only"
      origin_ssl_protocols     = ["TLSv1.2", "TLSv1.1", "TLSv1"]
    }
  }

  # Tell CloudFront what and how it should cache the content. Our site is very static, only GET and
  # HEAD requests are possible, so cache only those.
  #
  # Enabling compressed responses is always a good idea if your html or JavaScripts have several
  # hundreds of KB (a common case) - you will save quite a lot of traffic.
  default_cache_behavior {
    allowed_methods = ["GET", "HEAD"]
    cached_methods  = ["GET", "HEAD"]
    compress        = true

    # 1 day
    min_ttl = 86400

    # 30 days
    default_ttl = 2592000

    target_origin_id       = "${aws_s3_bucket.content.bucket_regional_domain_name}"
    viewer_protocol_policy = "redirect-to-https"

    # Do not forward query strings nor cookies to S3 when a request with any of these is made to
    # CloudFront.
    forwarded_values {
      query_string = false

      cookies {
        forward = "none"
      }
    }
  }

  # When you use custom domain and want to use HTTPS (you always want to do that!) this is the place
  # where you would specify the ACM certificate to be used.
  viewer_certificate {
    cloudfront_default_certificate = true
  }

  # No restrictions on this CloudFront access, but the configuration block is required by Terraform.
  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }
}

# Terraform holds quite a lot of information about each resource it manages, but it does not show
# any of them when it's done running. To see some of that information you have to define an
# "output". All outputs are visible on the console when Terraform finishes applying your changes and
# they can also be later retrieved using `terraform output`.
output "cloudfront_url" {
  value = "${aws_cloudfront_distribution.content.domain_name}"
}
