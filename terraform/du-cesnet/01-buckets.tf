resource "aws_s3_bucket" "longhorn_backups" {
  bucket = "longhorn-backups"
}

resource "aws_s3_bucket" "rag_evidence_prod" {
  bucket = "rag-evidence-prod"
}

resource "aws_s3_bucket" "rag_documents_prod" {
  bucket = "rag-documents-prod"
}

resource "aws_s3_bucket" "rag_embeddings_prod" {
  bucket = "rag-embeddings-prod"
}
