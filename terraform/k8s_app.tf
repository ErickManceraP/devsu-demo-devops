# ─────────────────────────────────────────────────────────────
# Kubernetes Application Resources
# Deployed after EKS cluster + node group are ready
# ─────────────────────────────────────────────────────────────

# Namespace
resource "kubernetes_namespace" "app" {
  metadata {
    name = var.app_namespace
    labels = {
      app = "devsu-demo-nodejs"
    }
  }

  depends_on = [aws_eks_node_group.main]
}

# ConfigMap — non-sensitive configuration
resource "kubernetes_config_map" "app" {
  metadata {
    name      = "devsu-demo-config"
    namespace = kubernetes_namespace.app.metadata[0].name
  }

  data = {
    NODE_ENV      = "production"
    PORT          = "8000"
    DATABASE_NAME = "/app/data/dev.sqlite"
  }
}

# Secret — sensitive credentials
resource "kubernetes_secret" "app" {
  metadata {
    name      = "devsu-demo-secret"
    namespace = kubernetes_namespace.app.metadata[0].name
  }

  type = "Opaque"

  data = {
    DATABASE_USER     = var.db_user
    DATABASE_PASSWORD = var.db_password
  }
}

# Deployment
resource "kubernetes_deployment" "app" {
  metadata {
    name      = "devsu-demo-nodejs"
    namespace = kubernetes_namespace.app.metadata[0].name
    labels = {
      app = "devsu-demo-nodejs"
    }
  }

  spec {
    replicas = 2

    selector {
      match_labels = {
        app = "devsu-demo-nodejs"
      }
    }

    strategy {
      type = "RollingUpdate"
      rolling_update {
        max_surge       = 1
        max_unavailable = 0
      }
    }

    template {
      metadata {
        labels = {
          app = "devsu-demo-nodejs"
        }
      }

      spec {
        security_context {
          run_as_non_root = true
          run_as_user     = 1001
          run_as_group    = 1001
          fs_group        = 1001
        }

        container {
          name              = "devsu-demo-nodejs"
          image             = var.app_image
          image_pull_policy = "Always"

          port {
            name           = "http"
            container_port = 8000
            protocol       = "TCP"
          }

          env_from {
            config_map_ref {
              name = kubernetes_config_map.app.metadata[0].name
            }
          }

          env {
            name = "DATABASE_USER"
            value_from {
              secret_key_ref {
                name = kubernetes_secret.app.metadata[0].name
                key  = "DATABASE_USER"
              }
            }
          }

          env {
            name = "DATABASE_PASSWORD"
            value_from {
              secret_key_ref {
                name = kubernetes_secret.app.metadata[0].name
                key  = "DATABASE_PASSWORD"
              }
            }
          }

          resources {
            requests = {
              cpu    = "100m"
              memory = "128Mi"
            }
            limits = {
              cpu    = "500m"
              memory = "256Mi"
            }
          }

          liveness_probe {
            http_get {
              path = "/api/users"
              port = 8000
            }
            initial_delay_seconds = 20
            period_seconds        = 30
            timeout_seconds       = 5
            failure_threshold     = 3
          }

          readiness_probe {
            http_get {
              path = "/api/users"
              port = 8000
            }
            initial_delay_seconds = 10
            period_seconds        = 15
            timeout_seconds       = 5
            failure_threshold     = 3
          }

          volume_mount {
            name       = "sqlite-data"
            mount_path = "/app/data"
          }

          security_context {
            allow_privilege_escalation = false
            read_only_root_filesystem  = false
            capabilities {
              drop = ["ALL"]
            }
          }
        }

        volume {
          name = "sqlite-data"
          empty_dir {}
        }
      }
    }
  }

  depends_on = [
    kubernetes_config_map.app,
    kubernetes_secret.app,
  ]
}

# Service
resource "kubernetes_service" "app" {
  metadata {
    name      = "devsu-demo-nodejs-svc"
    namespace = kubernetes_namespace.app.metadata[0].name
    labels = {
      app = "devsu-demo-nodejs"
    }
  }

  spec {
    type = "ClusterIP"

    selector = {
      app = "devsu-demo-nodejs"
    }

    port {
      name        = "http"
      protocol    = "TCP"
      port        = 80
      target_port = 8000
    }
  }
}

# Ingress
resource "kubernetes_ingress_v1" "app" {
  metadata {
    name      = "devsu-demo-ingress"
    namespace = kubernetes_namespace.app.metadata[0].name
    annotations = {
      "kubernetes.io/ingress.class"                    = "nginx"
      "nginx.ingress.kubernetes.io/rewrite-target"     = "/"
      "nginx.ingress.kubernetes.io/limit-rps"          = "20"
    }
  }

  spec {
    rule {
      host = "devsu-demo.local"
      http {
        path {
          path      = "/"
          path_type = "Prefix"
          backend {
            service {
              name = kubernetes_service.app.metadata[0].name
              port {
                number = 80
              }
            }
          }
        }
      }
    }
  }

  depends_on = [helm_release.nginx_ingress]
}

# Horizontal Pod Autoscaler
resource "kubernetes_horizontal_pod_autoscaler_v2" "app" {
  metadata {
    name      = "devsu-demo-hpa"
    namespace = kubernetes_namespace.app.metadata[0].name
  }

  spec {
    scale_target_ref {
      api_version = "apps/v1"
      kind        = "Deployment"
      name        = kubernetes_deployment.app.metadata[0].name
    }

    min_replicas = 2
    max_replicas = 5

    metric {
      type = "Resource"
      resource {
        name = "cpu"
        target {
          type                = "Utilization"
          average_utilization = 70
        }
      }
    }

    metric {
      type = "Resource"
      resource {
        name = "memory"
        target {
          type                = "Utilization"
          average_utilization = 80
        }
      }
    }

    behavior {
      scale_up {
        stabilization_window_seconds = 60
        select_policy                = "Max"
        policy {
          type           = "Pods"
          value          = 1
          period_seconds = 60
        }
      }
      scale_down {
        stabilization_window_seconds = 180
        select_policy                = "Min"
        policy {
          type           = "Pods"
          value          = 1
          period_seconds = 60
        }
      }
    }
  }
}
