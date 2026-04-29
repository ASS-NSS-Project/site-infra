# Terraform creates the folders with stable UIDs so that the Grafana sidecar
# (kube-prometheus-stack) finds them by title-lookup and reuses them instead
# of auto-creating new ones with random UIDs.
#
# ORDERING: apply this module BEFORE or AFTER the sidecar has run:
#   - Before sidecar: Terraform creates → sidecar finds → permissions hold. ✓
#   - After sidecar already created folders: the grafana_folder resource will
#     fail (duplicate title). Fix by importing the sidecar-created folder:
#
#       terraform import grafana_folder.kubernetes  <uid-from-grafana-api>
#       terraform import grafana_folder.rag_system  <uid-from-grafana-api>
#
#     Get the UID with:
#       curl -su admin:PASSWORD https://grafana.nss.jkzl.eu/api/folders | jq '.[] | {title,uid}'

# ---------------------------------------------------------------------------
# Kubernetes folder — receives all default kube-prometheus-stack dashboards.
# Restricted to Editor+; Viewers (rag_admin, rag_analyst) cannot see it.
# ---------------------------------------------------------------------------
resource "grafana_folder" "kubernetes" {
  title = "Kubernetes"
  uid   = "kubernetes"
}

resource "grafana_folder_permission" "kubernetes" {
  folder_uid = grafana_folder.kubernetes.uid
  permissions {
    role       = "Editor"
    permission = "Edit"
  }
}

# ---------------------------------------------------------------------------
# RAG System folder — receives the four custom RAG dashboards via the
# grafana_folder annotation on each ConfigMap.
# Viewers (rag_admin, rag_analyst) get View access here and nowhere else.
# ---------------------------------------------------------------------------
resource "grafana_folder" "rag_system" {
  title = "RAG System"
  uid   = "rag-system"
}

resource "grafana_folder_permission" "rag_system" {
  folder_uid = grafana_folder.rag_system.uid
  permissions {
    role       = "Editor"
    permission = "Edit"
  }
  permissions {
    role       = "Viewer"
    permission = "View"
  }
}
