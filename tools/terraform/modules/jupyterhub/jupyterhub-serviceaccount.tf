resource "kubernetes_service_account" "jupyterhub" {
  metadata {
    name      = "jupyterhub"
    namespace = "${var.namespace}"
  }
}
