
resource "google_compute_firewall" "default" {
  project                 = var.project_id
  name                    = local.name
  description             = var.description
  network                 = var.network
  priority                = coalesce(var.priority, 1000)
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
  target_service_accounts = local.target_service_accounts
}

locals {
  name                    = lower(coalesce(var.name, "${local.name_prefix}-${var.network}-${local.ports_as_string}"))
  name_prefix             = lower(coalesce(var.name_prefix, "fw"))
  direction               = upper(coalesce(var.direction, "ingress"))
  action                  = var.allow != null ? "ALLOW" : (var.deny != null ? "DENY" : upper(coalesce(var.action, "allow")))
  protocols               = var.protocols != null ? var.protocols : [local.protocol]
  protocol                = var.ports != null ? "tcp" : lower(coalesce(var.protocol, "all"))
  target_tags             = var.target_tags != null ? length(var.target_tags) > 0 ? var.target_tags : null : null
  target_service_accounts = var.target_service_accounts != null ? length(var.target_service_accounts) > 0 ? var.target_service_accounts : null : null
  traffic = [for protocol in local.protocols :
    {
      protocol = protocol
      ports    = var.ports
    }
  ]
  ports_as_string = var.ports != null ? join("-", var.ports) : "allports"
}