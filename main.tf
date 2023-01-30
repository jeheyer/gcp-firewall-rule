locals {
  name         = lower(coalesce(var.name, "${local.name_prefix}"))
  direction    = upper(coalesce(var.direction, "ingress"))
  action       = var.allow != null ? "ALLOW" : (var.deny != null ? "DENY" : upper(coalesce(var.action, "allow")))
  priority     = coalesce(var.priority, 1000)
  network_name = coalesce(var.network_name, var.network, "default")
  network_link = "projects/${var.project_id}/global/networks/${local.network_name}"
  ports        = var.ports != null ? var.ports : ( var.port != null ? [var.port] : null )
  protocols    = var.protocols != null ? var.protocols : [local.protocol]
  protocol     = var.ports != null || var.port != null ? "tcp" : lower(coalesce(var.protocol, "all"))
  traffic = [for protocol in local.protocols :
    {
      protocol = protocol
      ports    = local.ports
    }
  ]
  target_tags  = var.target_tags != null ? length(var.target_tags) > 0 ? var.target_tags : null : null
  target_sas   = var.target_service_accounts != null ? length(var.target_service_accounts) > 0 ? var.target_service_accounts : null : null
  rule_description_fields = [
    local.network_name,
    local.priority,
    substr(lower(local.direction), 0, 1),
    substr(lower(local.action), 0, 1),
    var.ports != null ? join("-", slice(local.ports, 0, 2)) : "allports",  # only use first two ports to keep string size small
  ]
  name_prefix = lower(coalesce(var.name_prefix, "fwr-${join("-", local.rule_description_fields)}"))
}

resource "google_compute_firewall" "default" {
  project                 = var.project_id
  name                    = local.name
  description             = var.description
  network                 = local.network_link
  priority                = local.priority
  direction               = local.direction
  source_ranges           = local.direction == "INGRESS" ? var.ranges : null
  source_tags             = local.direction == "INGRESS" ? var.source_tags : null
  source_service_accounts = local.direction == "INGRESS" ? var.source_service_accounts : null
  dynamic "allow" {
    for_each = var.allow != null ? var.allow : local.action == "ALLOW" ? local.traffic : []
    content {
      protocol = allow.value.protocol != null ? lower(allow.value.protocol) : null
      ports    = try(coalesce(allow.value.ports, var.ports), null)
    }
  }
  dynamic "deny" {
    for_each = var.deny != null ? var.deny : local.action == "DENY" ? local.traffic : []
    content {
      protocol = deny.value.protocol != null ? lower(deny.value.protocol) : null
      ports    = try(coalesce(deny.value.ports, var.ports), null)
    }
  }
  dynamic "log_config" {
    for_each = var.logging ? [true] : []
    content {
      metadata = "INCLUDE_ALL_METADATA"
    }
  }
  destination_ranges      = local.direction == "EGRESS" ? var.ranges : null
  target_tags             = local.target_tags
  target_service_accounts = local.target_sas
}

