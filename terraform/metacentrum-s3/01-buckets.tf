resource "aws_s3_bucket" "longhorn_backup" {
  bucket = "longhorn-backup"
}

resource "aws_s3_bucket" "rag_evidence" {
  bucket = "rag-evidence"
}

resource "aws_s3_bucket" "rag_documents" {
  bucket = "rag-documents"
}
