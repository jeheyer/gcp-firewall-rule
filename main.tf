locals {
  gen_short_name = var.name == null && var.short_name == null ? true : false
  short_name     = coalesce(var.short_name, local.gen_short_name ? one(random_string.short_name).result : "rule")
  rule_name      = var.name != null ? lower(var.name) : "${local.name_prefix}-${local.short_name}"
  direction      = upper(coalesce(var.direction, "ingress"))
  action         = var.allow != null ? "ALLOW" : (var.deny != null ? "DENY" : upper(coalesce(var.action, "allow")))
  priority       = coalesce(var.priority, 1000)
  network_name   = coalesce(var.network_name, var.network, "default")
  network_link   = "projects/${var.project_id}/global/networks/${local.network_name}"
  ports          = var.ports != null ? var.ports : (var.port != null ? [var.port] : null)
  protocols      = var.protocols != null ? var.protocols : [local.protocol]
  protocol       = var.ports != null || var.port != null ? "tcp" : lower(coalesce(var.protocol, "all"))
  traffic = [for protocol in local.protocols :
    {
      protocol = protocol
      ports    = local.ports
    }
  ]
  target_tags = var.target_tags != null ? length(var.target_tags) > 0 ? var.target_tags : null : null
  target_sas  = var.target_service_accounts != null ? length(var.target_service_accounts) > 0 ? var.target_service_accounts : null : null
  rule_description_fields = [
    local.network_name,
    local.priority,
    substr(lower(local.direction), 0, 1),
    substr(lower(local.action), 0, 1),
    local.ports != null ? join("-", slice(local.ports, 0, length(local.ports) == 1 ? 1 : 2)) : "allports", # only use first two ports to keep string size small
  ]
  #ranges = local.direction == "INGRESS" ? coalesce(var.ranges, ["169.254.169.254"])
  #source_type = var.source_service_accounts != null ? "sas" : (var.source_tags != null ? "tags" : "ranges") 
  name_prefix = lower(coalesce(var.name_prefix, "fwr-${join("-", local.rule_description_fields)}"))
  disabled    = !var.enforcement ? true : coalesce(var.disabled, false)
  ranges      = local.direction == "INGRESS" && var.source_service_accounts == null && var.source_tags == null && var.ranges == null ? ["169.254.169.254"] : null
}

resource "random_string" "short_name" {
  count   = local.gen_short_name ? 1 : 0
  length  = 4
  special = false
  upper   = false
}

resource "google_compute_firewall" "default" {
  project                 = var.project_id
  name                    = local.rule_name
  description             = var.description
  network                 = local.network_link
  priority                = local.priority
  direction               = local.direction
  disabled                = local.disabled
  source_ranges           = [] # null #["1.2.3.4"] #local.direction == "INGRESS" ? try(coalesce(var.ranges, local.ranges), ["127.0.0.1"]) : null
  source_tags             = local.direction == "INGRESS" ? var.source_tags : null
  source_service_accounts = local.direction == "INGRESS" ? var.source_service_accounts : null
  destination_ranges      = local.direction == "EGRESS" ? var.ranges : null
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
  target_tags             = local.target_tags
  target_service_accounts = local.target_sas
}

