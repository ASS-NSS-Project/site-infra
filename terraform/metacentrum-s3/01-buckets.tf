resource "aws_s3_bucket" "longhorn_backups" {
  bucket = "longhorn-backups"
}

resource "aws_s3_bucket" "rag_evidence_prod" {
  bucket = "rag-evidence-prod"
}

resource "aws_s3_bucket" "rag_documents_prod" {
  bucket = "rag-documents-prod"
}

resource "aws_s3_bucket" "rag_evidence_dev" {
  bucket = "rag-evidence-dev"
}

resource "aws_s3_bucket" "rag_documents_dev" {
  bucket = "rag-documents-dev"
}

resource "aws_s3_bucket_policy" "longhorn_backups" {
  bucket = aws_s3_bucket.longhorn_backups.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "DenyAnonymous"
        Effect    = "Deny"
        Principal = "*"
        Action    = "s3:*"
        Resource = [
          "arn:aws:s3:::longhorn-backups",
          "arn:aws:s3:::longhorn-backups/*",
        ]
        Condition = {
          StringEquals = {
            "aws:PrincipalType" = "Anonymous"
          }
        }
      }
    ]
  })
}

resource "aws_s3_bucket_policy" "rag_evidence_prod" {
  bucket = aws_s3_bucket.rag_evidence_prod.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "DenyAnonymous"
        Effect    = "Deny"
        Principal = "*"
        Action    = "s3:*"
        Resource = [
          "arn:aws:s3:::rag-evidence-prod",
          "arn:aws:s3:::rag-evidence-prod/*",
        ]
        Condition = {
          StringEquals = {
            "aws:PrincipalType" = "Anonymous"
          }
        }
      }
    ]
  })
}

resource "aws_s3_bucket_policy" "rag_evidence_dev" {
  bucket = aws_s3_bucket.rag_evidence_dev.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "DenyAnonymous"
        Effect    = "Deny"
        Principal = "*"
        Action    = "s3:*"
        Resource = [
          "arn:aws:s3:::rag-evidence-dev",
          "arn:aws:s3:::rag-evidence-dev/*",
        ]
        Condition = {
          StringEquals = {
            "aws:PrincipalType" = "Anonymous"
          }
        }
      }
    ]
  })
}

resource "aws_s3_bucket_policy" "rag_documents_prod" {
  bucket = aws_s3_bucket.rag_documents_prod.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "DenyAnonymous"
        Effect    = "Deny"
        Principal = "*"
        Action    = "s3:*"
        Resource = [
          "arn:aws:s3:::rag-documents-prod",
          "arn:aws:s3:::rag-documents-prod/*",
        ]
        Condition = {
          StringEquals = {
            "aws:PrincipalType" = "Anonymous"
          }
        }
      }
    ]
  })
}

resource "aws_s3_bucket_policy" "rag_documents_dev" {
  bucket = aws_s3_bucket.rag_documents_dev.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "DenyAnonymous"
        Effect    = "Deny"
        Principal = "*"
        Action    = "s3:*"
        Resource = [
          "arn:aws:s3:::rag-documents-dev",
          "arn:aws:s3:::rag-documents-dev/*",
        ]
        Condition = {
          StringEquals = {
            "aws:PrincipalType" = "Anonymous"
          }
        }
      }
    ]
  })
}
