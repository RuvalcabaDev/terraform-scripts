resource "aws_s3_bucket" "input_transactions" {
  bucket = "${local.prefix}-input-transactions"
  # acl    = "private" # ACLs están siendo desaconsejadas, usar políticas de bucket

  tags = {
    Name = "${local.prefix}-input-transactions"
  }
}

resource "aws_s3_bucket_public_access_block" "input_transactions_public_access" {
  bucket                  = aws_s3_bucket.input_transactions.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_versioning" "input_transactions_versioning" {
  bucket = aws_s3_bucket.input_transactions.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "input_transactions_encryption" {
  bucket = aws_s3_bucket.input_transactions.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}


resource "aws_s3_bucket" "output_reports" {
  bucket = "${local.prefix}-output-reports"

  tags = {
    Name = "${local.prefix}-output-reports"
  }
}

resource "aws_s3_bucket_public_access_block" "output_reports_public_access" {
  bucket                  = aws_s3_bucket.output_reports.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_versioning" "output_reports_versioning" {
  bucket = aws_s3_bucket.output_reports.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "output_reports_encryption" {
  bucket = aws_s3_bucket.output_reports.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# (Opcional) Bucket para artefactos de Lambda, si no usas ECR para Lambdas containerizadas
resource "aws_s3_bucket" "lambda_artifacts" {
  bucket = "${local.prefix}-lambda-artifacts"

  tags = {
    Name = "${local.prefix}-lambda-artifacts"
  }
}
resource "aws_s3_bucket_public_access_block" "lambda_artifacts_public_access" {
  bucket                  = aws_s3_bucket.lambda_artifacts.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}
