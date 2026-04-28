# RAG System folder — receives the two custom dashboards from sidecar ConfigMaps
resource "grafana_folder" "rag_system" {
  title = "RAG System"
  uid   = "rag-system"
}

# General (root) folder: strip Viewer permission so rag_admin/rag_analyst
# Viewers cannot browse default kube-prometheus-stack dashboards.
# Grafana Admin role bypasses all folder permissions — admin group unaffected.
resource "grafana_folder_permission" "general" {
  folder_uid = ""
  permissions {
    role       = "Editor"
    permission = "Edit"
  }
}

# RAG System folder: grant Viewer access so rag_admin/rag_analyst see only these dashboards
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
