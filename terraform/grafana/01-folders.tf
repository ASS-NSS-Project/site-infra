# Kubernetes folder — receives default kube-prometheus-stack dashboards.
# Restricted to Admin/Editor so Viewers (rag_admin, rag_analyst) cannot see them.
# Grafana Admin org role bypasses all folder permissions — admin group unaffected.
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

# RAG System folder — receives the two custom dashboards via sidecar grafana_folder annotation.
# Viewers (rag_admin, rag_analyst) are granted access here only.
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
