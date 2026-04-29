# Folders are created automatically by the Grafana sidecar (kube-prometheus-stack).
# Terraform must NOT recreate them — a duplicate title causes a 409 and breaks the
# grafana_folder resource, which in turn silently skips grafana_folder_permission.
# Instead, look the folders up by title and apply permissions to the real UIDs.
#
# NOTE: apply this module only after kube-prometheus-stack has synced and both
# folders exist (i.e. Grafana is accessible and the sidecar has loaded dashboards).

# ---------------------------------------------------------------------------
# Kubernetes folder — receives all default kube-prometheus-stack dashboards.
# Restricted to Editor+; Viewers (rag_admin, rag_analyst) cannot see it.
# ---------------------------------------------------------------------------
data "grafana_folder" "kubernetes" {
  title = "Kubernetes"
}

resource "grafana_folder_permission" "kubernetes" {
  folder_uid = data.grafana_folder.kubernetes.uid
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
data "grafana_folder" "rag_system" {
  title = "RAG System"
}

resource "grafana_folder_permission" "rag_system" {
  folder_uid = data.grafana_folder.rag_system.uid
  permissions {
    role       = "Editor"
    permission = "Edit"
  }
  permissions {
    role       = "Viewer"
    permission = "View"
  }
}
