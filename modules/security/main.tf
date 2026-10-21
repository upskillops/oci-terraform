resource "oci_core_network_security_group" "this" {
  for_each = toset(["cp", "workers", "pods", "lb", "db"])

  compartment_id = var.compartment_id
  vcn_id         = var.vcn_id
  display_name   = "${var.name_prefix}-nsg-${each.key}"
  freeform_tags  = var.tags
}

locals {
  nsg_ids = tomap({ for k, v in oci_core_network_security_group.this : k => v.id })

  api_ingress_cidrs = distinct(concat([var.cp_subnet_cidr], var.api_endpoint_allowed_cidrs))

  t_nsg  = "NETWORK_SECURITY_GROUP"
  t_svc  = "SERVICE_CIDR_BLOCK"
  t_cidr = "CIDR_BLOCK"

  d = { min = null, max = null, icmp_type = null, icmp_code = null }

  # Rules follow Oracle's OKE reference for VCN-native pod networking with a private API endpoint.
  rules_static = [
    # ---- Control plane (API endpoint) ----
    merge(local.d, { id = "cp-in-workers-6443", nsg = "cp", dir = "INGRESS", proto = "6", ptype = local.t_nsg, peer = "workers", min = 6443, max = 6443, desc = "Workers to Kubernetes API" }),
    merge(local.d, { id = "cp-in-workers-12250", nsg = "cp", dir = "INGRESS", proto = "6", ptype = local.t_nsg, peer = "workers", min = 12250, max = 12250, desc = "Workers to control plane" }),
    merge(local.d, { id = "cp-in-pods-6443", nsg = "cp", dir = "INGRESS", proto = "6", ptype = local.t_nsg, peer = "pods", min = 6443, max = 6443, desc = "Pods to Kubernetes API" }),
    merge(local.d, { id = "cp-in-pods-12250", nsg = "cp", dir = "INGRESS", proto = "6", ptype = local.t_nsg, peer = "pods", min = 12250, max = 12250, desc = "Pods to control plane" }),
    merge(local.d, { id = "cp-in-workers-icmp", nsg = "cp", dir = "INGRESS", proto = "1", ptype = local.t_nsg, peer = "workers", icmp_type = 3, icmp_code = 4, desc = "Path MTU discovery" }),
    merge(local.d, { id = "cp-eg-oci-443", nsg = "cp", dir = "EGRESS", proto = "6", ptype = local.t_svc, peer = var.oci_services_cidr, min = 443, max = 443, desc = "Control plane to OCI services" }),
    merge(local.d, { id = "cp-eg-workers-10250", nsg = "cp", dir = "EGRESS", proto = "6", ptype = local.t_nsg, peer = "workers", min = 10250, max = 10250, desc = "API to kubelet" }),
    merge(local.d, { id = "cp-eg-workers-icmp", nsg = "cp", dir = "EGRESS", proto = "1", ptype = local.t_nsg, peer = "workers", icmp_type = 3, icmp_code = 4, desc = "Path MTU discovery" }),
    merge(local.d, { id = "cp-eg-pods-all", nsg = "cp", dir = "EGRESS", proto = "all", ptype = local.t_nsg, peer = "pods", desc = "Control plane to pods (webhooks, aggregated APIs)" }),

    # ---- Workers ----
    merge(local.d, { id = "wk-in-workers-all", nsg = "workers", dir = "INGRESS", proto = "all", ptype = local.t_nsg, peer = "workers", desc = "Node to node" }),
    merge(local.d, { id = "wk-in-cp-10250", nsg = "workers", dir = "INGRESS", proto = "6", ptype = local.t_nsg, peer = "cp", min = 10250, max = 10250, desc = "API to kubelet" }),
    merge(local.d, { id = "wk-in-lb-nodeport", nsg = "workers", dir = "INGRESS", proto = "6", ptype = local.t_nsg, peer = "lb", min = 30000, max = 32767, desc = "LB to NodePorts" }),
    merge(local.d, { id = "wk-in-lb-10256", nsg = "workers", dir = "INGRESS", proto = "6", ptype = local.t_nsg, peer = "lb", min = 10256, max = 10256, desc = "LB to kube-proxy health check" }),
    merge(local.d, { id = "wk-in-pods-all", nsg = "workers", dir = "INGRESS", proto = "all", ptype = local.t_nsg, peer = "pods", desc = "Pods to nodes" }),
    merge(local.d, { id = "wk-in-icmp", nsg = "workers", dir = "INGRESS", proto = "1", ptype = local.t_cidr, peer = "0.0.0.0/0", icmp_type = 3, icmp_code = 4, desc = "Path MTU discovery" }),
    merge(local.d, { id = "wk-eg-all", nsg = "workers", dir = "EGRESS", proto = "all", ptype = local.t_cidr, peer = "0.0.0.0/0", desc = "Outbound via NAT / Service Gateway" }),

    # ---- Pods ----
    merge(local.d, { id = "pd-in-workers-all", nsg = "pods", dir = "INGRESS", proto = "all", ptype = local.t_nsg, peer = "workers", desc = "Nodes to pods" }),
    merge(local.d, { id = "pd-in-cp-all", nsg = "pods", dir = "INGRESS", proto = "all", ptype = local.t_nsg, peer = "cp", desc = "Control plane to pods" }),
    merge(local.d, { id = "pd-in-pods-all", nsg = "pods", dir = "INGRESS", proto = "all", ptype = local.t_nsg, peer = "pods", desc = "Pod to pod" }),
    merge(local.d, { id = "pd-eg-all", nsg = "pods", dir = "EGRESS", proto = "all", ptype = local.t_cidr, peer = "0.0.0.0/0", desc = "Outbound via NAT / Service Gateway" }),

    # ---- Load balancers ----
    merge(local.d, { id = "lb-eg-nodeport", nsg = "lb", dir = "EGRESS", proto = "6", ptype = local.t_nsg, peer = "workers", min = 30000, max = 32767, desc = "LB to NodePorts" }),
    merge(local.d, { id = "lb-eg-10256", nsg = "lb", dir = "EGRESS", proto = "6", ptype = local.t_nsg, peer = "workers", min = 10256, max = 10256, desc = "LB health check" }),

    # ---- MySQL HeatWave database ----
    merge(local.d, { id = "db-eg-oci-443", nsg = "db", dir = "EGRESS", proto = "6", ptype = local.t_svc, peer = var.oci_services_cidr, min = 443, max = 443, desc = "Database to OCI services" }),
  ]

  rules_api = [
    for c in local.api_ingress_cidrs : merge(local.d, {
      id    = "cp-in-api-${replace(replace(c, ".", "-"), "/", "-")}", nsg = "cp", dir = "INGRESS", proto = "6",
      ptype = local.t_cidr, peer = c, min = 6443, max = 6443, desc = "Admin access to API endpoint"
    })
  ]

  rules_lb = flatten([
    for c in var.lb_allowed_cidrs : [
      for p in var.lb_ports : merge(local.d, {
        id    = "lb-in-${replace(replace(c, ".", "-"), "/", "-")}-${p}", nsg = "lb", dir = "INGRESS", proto = "6",
        ptype = local.t_cidr, peer = c, min = p, max = p, desc = "Clients to load balancer"
      })
    ]
  ])

  rules_db = flatten([
    for p in var.mysql_ports : [
      merge(local.d, { id = "db-in-workers-${p}", nsg = "db", dir = "INGRESS", proto = "6", ptype = local.t_nsg, peer = "workers", min = p, max = p, desc = "Workers to MySQL" }),
      merge(local.d, { id = "db-in-pods-${p}", nsg = "db", dir = "INGRESS", proto = "6", ptype = local.t_nsg, peer = "pods", min = p, max = p, desc = "Pods to MySQL" }),
    ]
  ])

  rules_db_admin = flatten([
    for c in var.db_allowed_cidrs : [
      for p in var.mysql_ports : merge(local.d, {
        id    = "db-in-${replace(replace(c, ".", "-"), "/", "-")}-${p}", nsg = "db", dir = "INGRESS", proto = "6",
        ptype = local.t_cidr, peer = c, min = p, max = p, desc = "Admin / VPN access to MySQL"
      })
    ]
  ])

  rules = { for r in concat(local.rules_static, local.rules_api, local.rules_lb, local.rules_db, local.rules_db_admin) : r.id => r }
}

resource "oci_core_network_security_group_security_rule" "this" {
  for_each = local.rules

  network_security_group_id = local.nsg_ids[each.value.nsg]
  direction                 = each.value.dir
  protocol                  = each.value.proto
  description               = each.value.desc
  stateless                 = false

  source           = each.value.dir == "INGRESS" ? lookup(local.nsg_ids, each.value.peer, each.value.peer) : null
  source_type      = each.value.dir == "INGRESS" ? each.value.ptype : null
  destination      = each.value.dir == "EGRESS" ? lookup(local.nsg_ids, each.value.peer, each.value.peer) : null
  destination_type = each.value.dir == "EGRESS" ? each.value.ptype : null

  dynamic "tcp_options" {
    for_each = each.value.proto == "6" && each.value.min != null ? [1] : []
    content {
      destination_port_range {
        min = each.value.min
        max = each.value.max
      }
    }
  }

  dynamic "icmp_options" {
    for_each = each.value.proto == "1" ? [1] : []
    content {
      type = each.value.icmp_type
      code = each.value.icmp_code
    }
  }
}
