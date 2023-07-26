resource "kubernetes_stateful_set_v1" "minio" {
  metadata {
    name      = "minio"
    namespace = "default"
    labels = {
      "app.arpa.home/name" = "minio"
    }
  }
  spec {
    selector {
      match_labels = {
        "app.arpa.home/name" = "minio"
      }
    }
    service_name = "minio"
    replicas     = 1
    template {
      metadata {
        labels = {
          "app.arpa.home/name" = "minio"
        }
      }
      spec {
        container {
          name              = "main"
          image             = "quay.io/minio/minio:RELEASE.2023-07-21T21-12-44Z@sha256:8e5e9490cd50018457d53a447e9881eaef6a327b320991347c2ea01db5f3c784"
          image_pull_policy = "IfNotPresent"
          args = [
            "server",
            "/data",
            "--console-address",
            ":9001"
          ]
          env {
            name  = "TZ"
            value = "America/New_York"
          }
          env {
            name = "MINIO_ROOT_USER"
            value = "${module.onepassword_item_storage.fields.minio_root_user}"
          }
          env {
            name = "MINIO_ROOT_PASSWORD"
            value = "${module.onepassword_item_storage.fields.minio_root_password}"
          }
          env {
            name  = "MINIO_API_CORS_ALLOW_ORIGIN"
            value = "http://minio.greyrock.io,http://s3.greyrock.io"
          }
          env {
            name  = "MINIO_BROWSER_REDIRECT_URL"
            value = "http://minio.greyrock.io"
          }
          env {
            name  = "MINIO_PROMETHEUS_JOB_ID"
            value = "minio"
          }
          env {
            name  = "MINIO_PROMETHEUS_URL"
            value = "https://prometheus.greyrock.tech"
          }
          env {
            name  = "MINIO_PROMETHEUS_AUTH_TYPE"
            value = "public"
          }
          env {
            name  = "MINIO_SERVER_URL"
            value = "http://s3.greyrock.io"
          }
          env {
            name  = "MINIO_UPDATE"
            value = "off"
          }
          port {
            name           = "console"
            container_port = 9001
            host_port      = 9001
          }
          port {
            name           = "s3"
            container_port = 9000
            host_port      = 9000
          }
          liveness_probe {
            http_get {
              path = "/minio/health/live"
              port = 9000
            }
            initial_delay_seconds = 30
            period_seconds        = 30
            failure_threshold     = 6
            timeout_seconds       = 10
          }
          readiness_probe {
            http_get {
              path = "/minio/health/live"
              port = 9000
            }
            initial_delay_seconds = 30
            period_seconds        = 30
            failure_threshold     = 6
            timeout_seconds       = 10
          }
          volume_mount {
            name       = "config"
            mount_path = "/data"
          }
          resources {
            requests = {
              cpu    = "1"
              memory = "2Gi"
            }
            limits = {
              memory = "4Gi"
            }
          }
        }
        security_context {
          run_as_user = 568
          run_as_group = 568
          fs_group = 568
          fs_group_change_policy = "OnRootMismatch"
          supplemental_groups = [
            100
          ]
        }
        toleration {
          effect   = "NoSchedule"
          operator = "Exists"
        }
        volume {
          name = "config"
          host_path {
            path = "/speedy/minio"
          }
        }
      }
    }
    update_strategy {
      type = "RollingUpdate"
    }
  }
}

resource "kubernetes_manifest" "traefik_config" {
  manifest = {
    "apiVersion" = "helm.cattle.io/v1"
    "kind"       = "HelmChartConfig"
    "metadata" = {
      "name"      = "traefik"
      "namespace" = "kube-system"
    }
    "spec" = {
      "valuesContent" = <<EOF
        ports:
          web:
            redirectTo: websecure
      EOF
    }
  }
}

resource "kubernetes_service_v1" "minio" {
  metadata {
    name      = "minio"
    namespace = "default"
    labels = {
      "app.arpa.home/name" = "minio"
    }
  }
  spec {
    selector = {
      "app.arpa.home/name" = "minio"
    }
    port {
      name        = "console"
      port        = 9001
      target_port = 9001
      protocol    = "TCP"
    }
    port {
      name        = "s3"
      port        = 9000
      target_port = 9000
      protocol    = "TCP"
    }
  }
}

resource "kubernetes_ingress_v1" "minio" {
  metadata {
    name      = "minio-console"
    namespace = "default"
    labels = {
      "app.arpa.home/name" = "minio"
    }
  }
  spec {
    ingress_class_name = "traefik"
    tls {
      secret_name = "greyrock-io-tls"
    }
    rule {
      host = "minio.greyrock.io"
      http {
        path {
          path      = "/"
          path_type = "Prefix"
          backend {
            service {
              name = "minio"
              port {
                number = 9001
              }
            }
          }
        }
      }
    }
  }
}

resource "kubernetes_ingress_v1" "s3" {
  metadata {
    name      = "minio-s3"
    namespace = "default"
    annotations = {
      "traefik.ingress.kubernetes.io/router.entrypoints" = "websecure"
    }
    labels = {
      "app.arpa.home/name" = "minio"
    }
  }
  spec {
    ingress_class_name = "traefik"
    rule {
      host = "s3.greyrock.io"
      http {
        path {
          path      = "/"
          path_type = "Prefix"
          backend {
            service {
              name = "minio"
              port {
                number = 9000
              }
            }
          }
        }
      }
    }
  }
}
