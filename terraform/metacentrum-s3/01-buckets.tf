resource "aws_s3_bucket" "longhorn_backup" {
  bucket = "longhorn-backup"
}

resource "aws_s3_bucket_acl" "longhorn_backup" {
  bucket = aws_s3_bucket.longhorn_backup.id
  acl    = "private"
}

resource "aws_s3_bucket_public_access_block" "longhorn_backup" {
  bucket                  = aws_s3_bucket.longhorn_backup.id
  block_public_acls       = true
  ignore_public_acls      = true
  block_public_policy     = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket" "rag_evidence" {
  bucket = "rag-evidence"
}

resource "aws_s3_bucket_acl" "rag_evidence" {
  bucket = aws_s3_bucket.rag_evidence.id
  acl    = "private"
}

resource "aws_s3_bucket_public_access_block" "rag_evidence" {
  bucket                  = aws_s3_bucket.rag_evidence.id
  block_public_acls       = true
  ignore_public_acls      = true
  block_public_policy     = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket" "rag_documents" {
  bucket = "rag-documents"
}

resource "aws_s3_bucket_acl" "rag_documents" {
  bucket = aws_s3_bucket.rag_documents.id
  acl    = "private"
}

resource "aws_s3_bucket_public_access_block" "rag_documents" {
  bucket                  = aws_s3_bucket.rag_documents.id
  block_public_acls       = true
  ignore_public_acls      = true
  block_public_policy     = true
  restrict_public_buckets = true
}
