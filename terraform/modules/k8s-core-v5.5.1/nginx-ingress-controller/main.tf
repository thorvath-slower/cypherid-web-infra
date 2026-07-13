locals {
  # If and set statements compatible with server-snippets: 
  # set: https://nginx.org/en/docs/http/ngx_http_rewrite_module.html#set
  # if: https://nginx.org/en/docs/http/ngx_http_rewrite_module.html#if
  geo_restriction_server_snippet = <<EOF
uninitialized_variable_warn off;
set $geoip_enabled        true;
set $ip_country_code      $geoip2_country_code;
if ($allowed_country = no) {
  return 451;
}
EOF
  general_server_snippet         = <<EOF
uninitialized_variable_warn off;
EOF

  # map is compatible with http-snippets:
  # map: https://nginx.org/en/docs/http/ngx_http_map_module.html#map
  cluster_geo_restriction_http_snippet = <<EOF
map $geoip2_country_code $allowed_country {
%{for country in var.cluster_geo_restriction.deny}
  ${country} no;
%{endfor}
%{for country in var.cluster_geo_restriction.allow}
  ${country} yes;
%{endfor}
  default ${var.cluster_geo_restriction.default == "allow" ? "yes" : "no"};
}
EOF

  load_geoip_inline_snippets = var.enable_geo_ip_config && var.cluster_geo_restriction != null
}
resource "kubernetes_manifest" "nginx_issuer" {
  manifest = {
    "apiVersion" = "cert-manager.io/v1"
    "kind"       = "ClusterIssuer"
    "metadata" = {
      "name" = "nginx-issuer"
    }
    "spec" = {
      "selfSigned" = {}
    }
  }
}

resource "helm_release" "nginx_ingress" {
  name             = "nginx-ingress"
  repository       = "https://kubernetes.github.io/ingress-nginx"
  chart            = "ingress-nginx"
  version          = var.nginx_version
  namespace        = var.namespace
  create_namespace = true
  # CZID-93: helm provider v3 replaced the repeated `set {}` blocks (static and
  # `dynamic "set"`) with a single `set = [{...}]` list attribute. The former
  # dynamic blocks become conditional/for-expression list fragments joined with
  # concat(). Every element carries name/value/type (type = null == unset) and
  # values are strings so the list has a single, well-formed element type.
  set = concat(
    [
      {
        name  = "controller.allowSnippetAnnotations"
        value = "true"
        type  = null
      },
      {
        name  = "controller.service.type"
        value = "NodePort"
        type  = null
      },
      {
        name  = "controller.podAnnotations.linkerd\\.io/inject"
        value = var.linkerd_annotations.linkerd_inject
        type  = "string"
      },
      {
        name  = "controller.podAnnotations.config\\.alpha\\.linkerd\\.io/proxy-wait-before-exit-seconds"
        value = var.linkerd_annotations.proxy_wait_before_exit_seconds
        type  = "string"
      },
      {
        name  = "controller.config.proxy-buffer-size"
        value = "16k"
        type  = "string"
      },
      {
        name  = "controller.config.client-body-buffer-size"
        value = "32k"
        type  = "string"
      },
      {
        name  = "controller.config.annotations-risk-level"
        value = "Critical"
        type  = "string"
      },
      {
        name  = "controller.config.strict-validate-path-type"
        value = "false"
        type  = "string"
      },
      {
        name  = "controller.replicaCount"
        value = tostring(var.replicas)
        type  = null
      },
      {
        name  = "controller.config.use-proxy-protocol"
        value = var.enable_proxy_protocol_v2 ? "true" : "false"
        type  = "string"
      },
      {
        name  = "controller.autoscaling.enabled"
        value = var.enable_autoscaling ? "true" : "false"
        type  = "auto"
      },
      {
        name  = "controller.autoscaling.minReplicas"
        value = tostring(var.min_replicas)
        type  = null
      },
      {
        name  = "controller.autoscaling.maxReplicas"
        value = tostring(var.max_replicas)
        type  = null
      },
      {
        name  = "controller.service.externalTrafficPolicy"
        value = var.external_traffic_policy
        type  = "string"
      },
      {
        name  = "controller.config.allow-snippet-annotations"
        value = "true"
        type  = null
      },
      {
        name  = "controller.config.proxy-body-size"
        value = var.proxy_body_size
        type  = "string"
      },
      {
        name  = "controller.resources.requests.cpu"
        value = var.controller_cpu_request
        type  = "string"
      },
      {
        name  = "controller.resources.requests.memory"
        value = var.controller_memory_request
        type  = "string"
      },
    ],
    var.enable_metrics ? [{
      name  = "controller.metrics.enabled"
      value = "true"
      type  = "string"
    }] : [],
    var.enable_prometheus_scraping ? [{
      name  = "controller.podAnnotations.prometheus\\.io/port"
      value = "10254"
      type  = "string"
    }] : [],
    var.enable_prometheus_scraping ? [{
      name  = "controller.podAnnotations.prometheus\\.io/scrape"
      value = "true"
      type  = "string"
    }] : [],
    [for k, v in var.extra_args : {
      name  = "controller.extraArgs.${k}"
      value = v
      type  = null
    }],
    [for k, v in var.extra_config_settings : {
      name  = "controller.config.${k}"
      value = v
      type  = null
    }],
    [{
      name  = "controller.config.allow-snippet-annotations"
      value = "true"
      type  = null
    }],
    var.enable_geo_ip_config ? [{
      name  = "controller.config.use-geoip"
      value = "false"
      type  = null
    }] : [],
    var.enable_geo_ip_config ? [{
      name  = "controller.config.use-geoip2"
      value = "true"
      type  = null
    }] : [],
    local.load_geoip_inline_snippets ? [{
      name  = "controller.config.http-snippet"
      value = local.cluster_geo_restriction_http_snippet
      type  = null
    }] : [],
    # https://stackoverflow.com/a/30550574
    local.load_geoip_inline_snippets ? [{
      name  = "controller.config.server-snippet"
      value = local.geo_restriction_server_snippet
      type  = null
    }] : [],
    # We need to set this in place if the argus app attempts to set a variable but this doesn't have it
    local.load_geoip_inline_snippets ? [] : [{
      name  = "controller.config.server-snippet"
      value = local.general_server_snippet
      type  = null
    }],
  )

  values = [templatefile("${path.module}/templates/values.yaml", {
    role_arn = module.eks_service_account_nginx_role.iam_role_arn
  })]

}

