resource "kubernetes_persistent_volume_claim" "jupyterhub_home" {
  metadata {
    name      = "jupyterhub-physpvc"
    namespace = "${var.namespace}"

    labels {
      name = "jupyterhub-home"
    }
  }

  spec {
    access_modes = ["ReadWriteOnce"]

    resources {
      requests {
        storage = "1Gi"
      }
    }
  }
}
