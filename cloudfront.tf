resource "aws_cloudfront_distribution" "static_hosting" {
  enabled = true

  # オリジンの設定
  origin {
    origin_id   = aws_s3_bucket.static_hosting.id
    domain_name = aws_s3_bucket.static_hosting.bucket_regional_domain_name
    # OACを設定
    origin_access_control_id = aws_cloudfront_origin_access_control.static_hosting.id
  }

  viewer_certificate {
    cloudfront_default_certificate = true
  }

  default_cache_behavior {
    target_origin_id       = aws_s3_bucket.static_hosting.id
    viewer_protocol_policy = "redirect-to-https"
    cached_methods         = ["GET", "HEAD"]
    allowed_methods        = ["GET", "HEAD"]
    forwarded_values {
      query_string = false
      headers      = []
      cookies {
        forward = "none"
      }
    }
    min_ttl     = 60
    default_ttl = 60
    max_ttl     = 60
  }

  default_root_object = "index.html"

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }
}

# OAC を作成
resource "aws_cloudfront_origin_access_control" "static_hosting" {
  name                              = "${var.prefix}-oac"
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}

# ディストリビューションのドメイン名を表示
output "cloudfront_distribution_domain_name" {
  description = "The domain name of the CloudFront distribution"
  value       = aws_cloudfront_distribution.static_hosting.domain_name
}
