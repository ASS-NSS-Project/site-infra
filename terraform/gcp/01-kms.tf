# --- GCP KMS — Vault auto-unseal ---
# Vault calls GCP KMS to encrypt/decrypt its master key on every (re)start,
# eliminating the need for manual unseal after pod restarts.

locals {
  ansible_root = "${path.module}/../../ansible"
}

resource "google_project_service" "kms" {
  service            = "cloudkms.googleapis.com"
  disable_on_destroy = true
}

resource "google_kms_key_ring" "vault" {
  name     = "vault-keyring"
  location = "global"

  depends_on = [google_project_service.kms]
}

resource "google_kms_crypto_key" "vault_unseal" {
  name            = "vault-unseal-key"
  key_ring        = google_kms_key_ring.vault.id
  rotation_period = "7776000s" # 90 days
}

# Service account Vault uses to authenticate to GCP KMS
resource "google_service_account" "vault_kms" {
  account_id   = "vault-kms-unseal"
  display_name = "Vault KMS auto-unseal"
}

resource "google_kms_crypto_key_iam_member" "vault_kms_encrypter_decrypter" {
  crypto_key_id = google_kms_crypto_key.vault_unseal.id
  role          = "roles/cloudkms.cryptoKeyEncrypterDecrypter"
  member        = "serviceAccount:${google_service_account.vault_kms.email}"
}

resource "google_kms_crypto_key_iam_member" "vault_kms_viewer" {
  crypto_key_id = google_kms_crypto_key.vault_unseal.id
  role          = "roles/cloudkms.viewer"
  member        = "serviceAccount:${google_service_account.vault_kms.email}"
}

# JSON key written to ansible/files/vault/ — mounted into the Vault pod via a K8s secret
resource "google_service_account_key" "vault_kms" {
  service_account_id = google_service_account.vault_kms.name
}

resource "local_file" "vault_kms_sa_key" {
  filename        = "${local.ansible_root}/files/vault/kms-sa-key.json"
  content         = base64decode(google_service_account_key.vault_kms.private_key)
  file_permission = "0600"
}

# --- Outputs ---

output "vault_kms_key_ring" {
  value = google_kms_key_ring.vault.id
}

output "vault_kms_crypto_key" {
  value = google_kms_crypto_key.vault_unseal.id
}

output "vault_kms_sa_email" {
  value = google_service_account.vault_kms.email
}
