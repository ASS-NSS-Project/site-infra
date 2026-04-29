# RAG System folder — receives all four RAG dashboards via the grafana_folder
# annotation on each ConfigMap. Viewers (rag_admin, rag_analyst) can only see
# this folder; no other folders are provisioned.
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
