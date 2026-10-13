#!/opt/saltstack/salt/bin/python3
"""Register Salt minions in NetBox as VMs, with their LAN and Tailscale IPs.

Run on the Salt master as root, with onedir's Python (it has salt and requests):

    /opt/saltstack/salt/bin/python3 tools/netbox-sync-minions.py            # dry run
    /opt/saltstack/salt/bin/python3 tools/netbox-sync-minions.py --apply    # write
    add --devices to include physical minions as Devices

- NetBox VM name = Salt minion ID, which is what the NetBox ext_pillar matches on.
- Existing IP address objects are reused (matched on host address, any mask), never
  duplicated. An IP already assigned to something else is reported, not moved.
- Tailscale IPs (100.64.0.0/10) get the `tailscale` tag and a <host>.<tailnet> DNS
  name. The VM's primary IPv4 is its first LAN address.
- Physical minions become Devices with --devices, using DEVICE_PLAN below for site
  and role, and the manufacturer/productname grains for the device type. Physical
  minions not in DEVICE_PLAN are skipped. On sites other than `home` only the
  Tailscale IP is recorded (a remote LAN can overlap ours) and is the primary.
- --appliances adds the non-minion APPLIANCES below as VMs with role `appliance`.
- The API token is read from NETBOX_TOKEN or prompted for; it's never stored.

Safe to re-run: anything already correct is left alone.
"""

import argparse
import getpass
import ipaddress
import os
import re
import sys

import requests
import salt.client

KEEP_IFACES = ("eth", "ens", "enp", "eno", "wlan", "wlp", "tailscale")
# Proxmox puts the host's LAN IP on its bridge.
KEEP_DEVICE_IFACES = KEEP_IFACES + ("vmbr",)
TAILNET_RANGE = ipaddress.ip_network("100.64.0.0/10")
VMINTERFACE = "virtualization.vminterface"
DCIM_INTERFACE = "dcim.interface"
HOME_SITE = "home"

# Physical minions: minion ID -> (site name, role). Decided 2026-10-13.
DEVICE_PLAN = {
    "proxmox": ("home", "hypervisor"),
    "wopr": ("home", "workstation"),
    "nlremote.taile3eee.ts.net": ("Bastion Maurits", "remote-node"),
}

# Not Salt minions, so no grains: VMs in the cluster with one fixed LAN IP on eth0.
# Added with --appliances. Decided 2026-10-13.
APPLIANCES = {
    "homeassistant": "192.168.0.24/24",
    "truenas": "192.168.0.3/24",
}
APPLIANCE_ROLE = "appliance"


class NetBox:
    def __init__(self, url, token, apply):
        self.api = url.rstrip("/") + "/api"
        self.apply = apply
        self.session = requests.Session()
        self.session.headers["Accept"] = "application/json"
        # NetBox 4.5 v2 tokens go as "Bearer nbt_<key>.<token>"; the UI copy may or
        # may not carry the nbt_ prefix. v1 tokens go as "Token <token>". Try each
        # form against /status/ and keep the first one NetBox accepts.
        self.candidates = []
        if "." in token:
            if not token.startswith("nbt_"):
                self.candidates.append(("Bearer, nbt_ added", f"Bearer nbt_{token}"))
            self.candidates.append(("Bearer, as pasted", f"Bearer {token}"))
        self.candidates.append(("Token, as pasted", f"Token {token}"))
        self.token_shape = f"{len(token)} chars, {'with' if token.startswith('nbt_') else 'no'} nbt_ prefix"

    def status(self):
        tried = []
        for label, header in self.candidates:
            self.session.headers["Authorization"] = header
            r = self.session.get(f"{self.api}/status/", timeout=30)
            if r.ok:
                print(f"Auth OK: {label}")
                return r.json()
            tried.append(f"{label} -> {r.status_code} {r.text[:120]}")
        sys.exit("FAIL: NetBox rejected every auth form. Token " + self.token_shape + "\n  "
                 + "\n  ".join(tried))

    def find(self, path, **params):
        r = self.session.get(f"{self.api}/{path}/", params=params, timeout=30)
        if not r.ok:
            sys.exit(f"FAIL: GET {path} {params}: {r.status_code} {r.text[:200]}")
        return r.json()["results"]

    def one(self, path, **params):
        found = self.find(path, **params)
        if len(found) > 1:
            sys.exit(f"FAIL: more than one {path} matches {params}")
        return found[0] if found else None

    def create(self, path, data, what):
        print(f"  CREATE {what}")
        if not self.apply:
            return {"id": None, **data}
        r = self.session.post(f"{self.api}/{path}/", json=data, timeout=30)
        if not r.ok:
            sys.exit(f"FAIL: creating {what}: {r.status_code} {r.text[:300]}")
        return r.json()

    def update(self, path, obj_id, data, what):
        print(f"  UPDATE {what}: {', '.join(sorted(data))}")
        if not self.apply or obj_id is None:
            return
        r = self.session.patch(f"{self.api}/{path}/{obj_id}/", json=data, timeout=30)
        if not r.ok:
            sys.exit(f"FAIL: updating {what}: {r.status_code} {r.text[:300]}")


def ensure_cluster(nb, name):
    cluster = nb.one("virtualization/clusters", name=name)
    if cluster:
        return cluster["id"]
    existing = [c["name"] for c in nb.find("virtualization/clusters")]
    if existing:
        print(f"NOTE: clusters already in NetBox: {', '.join(existing)} (use --cluster to pick one)")
    ctype = nb.one("virtualization/cluster-types", slug="proxmox") or nb.create(
        "virtualization/cluster-types", {"name": "Proxmox", "slug": "proxmox"}, "cluster type Proxmox"
    )
    return nb.create(
        "virtualization/clusters", {"name": name, "type": ctype["id"], "status": "active"}, f"cluster {name}"
    )["id"]


def ensure_tag(nb, slug):
    tag = nb.one("extras/tags", slug=slug) or nb.create(
        "extras/tags", {"name": slug, "slug": slug}, f"tag {slug}"
    )
    return tag["id"]


def prefixlen(netmask):
    return ipaddress.ip_network(f"0.0.0.0/{netmask}").prefixlen


def slugify(text):
    return re.sub(r"[^a-z0-9]+", "-", text.lower()).strip("-")


# (path, slug) -> id, so a dry run lists each new site/role/type once, not per device.
_ensured = {}


def ensure_named(nb, path, name, what, **extra):
    """Find by slug, or create with name + slug (+ extra fields)."""
    slug = slugify(name)
    if (path, slug) not in _ensured:
        # Match an existing object by name too: its slug may not be ours.
        obj = (nb.one(path, slug=slug) or nb.one(path, name__ie=name)
               or nb.create(path, {"name": name, "slug": slug, **extra}, f"{what} {name}"))
        _ensured[(path, slug)] = obj["id"]
    return _ensured[(path, slug)]


def ensure_device_type(nb, manufacturer, model):
    mfr_id = ensure_named(nb, "dcim/manufacturers", manufacturer, "manufacturer")
    slug = slugify(f"{manufacturer} {model}")
    if ("dcim/device-types", slug) not in _ensured:
        dtype = nb.one("dcim/device-types", slug=slug) or nb.create(
            "dcim/device-types", {"manufacturer": mfr_id, "model": model, "slug": slug},
            f"device type {manufacturer} {model}",
        )
        _ensured[("dcim/device-types", slug)] = dtype["id"]
    return _ensured[("dcim/device-types", slug)]


def iface_type(name):
    if name.startswith("tailscale"):
        return "virtual"
    if name.startswith(("vmbr", "br")):
        return "bridge"
    return "other"  # real NIC speed/type: refine by hand in NetBox


def sync_ip(nb, minion, iface, addr, dns_name, tag_id, counts, obj_type):
    """Create or attach one IP. Returns its NetBox id (None in a dry run)."""
    host = addr["address"]
    cidr = f"{host}/{prefixlen(addr['netmask'])}"
    label = f"{minion} {iface['name']} {cidr}"
    want = {
        "assigned_object_type": obj_type,
        "assigned_object_id": iface["id"],
        "dns_name": dns_name,
    }

    net = ipaddress.ip_interface(cidr).network
    if net.prefixlen < 31 and ipaddress.ip_address(host) in (net.network_address, net.broadcast_address):
        print(f"  WARN {label}: network or broadcast address, NetBox won't assign it. Skipped; check the host's config")
        counts["warn"] += 1
        return None

    found = nb.find("ipam/ip-addresses", address=host)
    if len(found) > 1:
        print(f"  WARN {label}: {len(found)} IP objects for {host} in NetBox, skipped. Merge them by hand")
        counts["warn"] += 1
        return None
    if not found:
        data = {"address": cidr, "status": "active", **want}
        if tag_id:
            data["tags"] = [tag_id]
        counts["changed"] += 1
        return nb.create("ipam/ip-addresses", data, f"IP {label}")["id"]

    ip = found[0]
    if ip["address"] != cidr:
        print(f"  WARN {label}: NetBox has {ip['address']} (mask differs), left as is")
        counts["warn"] += 1
    owner_type, owner_id = ip.get("assigned_object_type"), ip.get("assigned_object_id")
    if owner_id and (owner_type != obj_type or (iface["id"] and owner_id != iface["id"])):
        print(f"  CONFLICT {label}: already assigned to {owner_type} {owner_id}, skipped")
        counts["warn"] += 1
        return None

    patch = {k: v for k, v in want.items() if ip.get(k) != v}
    if tag_id:
        tag_ids = {t["id"] for t in ip.get("tags", [])}
        if tag_id not in tag_ids:
            patch["tags"] = sorted(tag_ids | {tag_id})
    if patch:
        counts["changed"] += 1
        nb.update("ipam/ip-addresses", ip["id"], patch, f"IP {label}")
    return ip["id"]


def sync_host(nb, args, minion, host, ifaces, obj, kind, tag_id, counts):
    """Interfaces, IPs and primary IPv4 for one VM or Device already in NetBox."""
    if kind == "vm":
        obj_path, if_path, parent, obj_type, keep = (
            "virtualization/virtual-machines", "virtualization/interfaces",
            "virtual_machine", VMINTERFACE, KEEP_IFACES)
        lan_ok = True
    else:
        obj_path, if_path, parent, obj_type, keep = (
            "dcim/devices", "dcim/interfaces", "device", DCIM_INTERFACE, KEEP_DEVICE_IFACES)
        lan_ok = DEVICE_PLAN[minion][0] == HOME_SITE

    primary = None
    for name, data in sorted(ifaces.items()):
        addrs = data.get("inet") or []
        if not name.startswith(keep) or not addrs:
            continue
        is_ts_iface = all(ipaddress.ip_address(a["address"]) in TAILNET_RANGE for a in addrs)
        if not lan_ok and not is_ts_iface:
            print(f"  SKIP {name}: LAN IPs not recorded for a remote site")
            continue
        iface = obj["id"] and nb.one(if_path, **{f"{parent}_id": obj["id"]}, name=name)
        if not iface:
            counts["changed"] += 1
            data_new = {parent: obj["id"], "name": name}
            if kind == "device":
                data_new["type"] = iface_type(name)
            iface = nb.create(if_path, data_new, f"{minion} interface {name}")
        for addr in addrs:
            is_ts = ipaddress.ip_address(addr["address"]) in TAILNET_RANGE
            dns = f"{host}.{args.tailnet}" if is_ts else host
            ip_id = sync_ip(nb, minion, iface, addr, dns, tag_id if is_ts else None, counts, obj_type)
            # Primary is the first LAN IP; on a remote site, the Tailscale IP.
            # A skipped IP (conflict, duplicates) returns None even when applying;
            # never let that clear the primary IP.
            if (is_ts != lan_ok) and primary is None and (ip_id or not args.apply):
                primary = (ip_id, addr["address"])

    current = (obj.get("primary_ip4") or {}).get("id")
    if primary and (primary[0] is None or current != primary[0]):
        counts["changed"] += 1
        nb.update(obj_path, obj["id"], {"primary_ip4": primary[0]},
                  f"{minion} primary IPv4 -> {primary[1]}")


def main():
    ap = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    ap.add_argument("--apply", action="store_true", help="write to NetBox (default: dry run)")
    ap.add_argument("--devices", action="store_true", help="also sync physical minions in DEVICE_PLAN")
    ap.add_argument("--appliances", action="store_true", help="also sync the fixed APPLIANCES VMs")
    ap.add_argument("--url", default="https://netbox.taile3eee.ts.net")
    ap.add_argument("--cluster", default="proxmox", help="NetBox cluster for new VMs")
    ap.add_argument("--tailnet", default="taile3eee.ts.net")
    ap.add_argument("--target", default="*", help="Salt glob of minions to sync")
    args = ap.parse_args()

    token = (os.environ.get("NETBOX_TOKEN") or getpass.getpass("NetBox API token: ")).strip()
    # NetBox 4.5's copy button gives the whole header value, "Bearer nbt_...".
    for scheme in ("bearer ", "token "):
        if token.lower().startswith(scheme):
            token = token[len(scheme):].strip()
    if not token:
        sys.exit("FAIL: empty token (the paste didn't arrive). Run it again")
    nb = NetBox(args.url, token, args.apply)
    print(f"NetBox {nb.status().get('netbox-version', '?')} at {args.url}. "
          f"{'APPLYING CHANGES' if args.apply else 'DRY RUN, nothing is written'}")

    local = salt.client.LocalClient()
    grains = local.cmd(args.target, "grains.item",
                       ["virtual", "host", "manufacturer", "productname"], timeout=30)
    ifaces = local.cmd(args.target, "network.interfaces", timeout=30)
    print(f"{len(grains)} minions answered\n")

    cluster_id = ensure_cluster(nb, args.cluster)
    tag_id = ensure_tag(nb, "tailscale")
    counts = {"changed": 0, "warn": 0, "skipped": 0}

    for minion in sorted(grains):
        print(f"{minion}")
        g = grains[minion]
        host = g.get("host") or minion

        if g.get("virtual") != "physical":
            obj = nb.one("virtualization/virtual-machines", name__ie=minion)
            if obj and obj["name"] != minion:
                print(f"  WARN NetBox VM is named {obj['name']!r}; ext_pillar needs {minion!r}. Rename it")
                counts["warn"] += 1
            if not obj:
                counts["changed"] += 1
                obj = nb.create("virtualization/virtual-machines",
                                {"name": minion, "cluster": cluster_id, "status": "active"},
                                f"VM {minion}")
            sync_host(nb, args, minion, host, ifaces.get(minion, {}), obj, "vm", tag_id, counts)
            continue

        if not args.devices or minion not in DEVICE_PLAN:
            why = "not in DEVICE_PLAN" if args.devices else "run with --devices"
            print(f"  SKIP physical: {why}")
            counts["skipped"] += 1
            continue

        site, role = DEVICE_PLAN[minion]
        manufacturer, model = g.get("manufacturer", "").strip(), g.get("productname", "").strip()
        if not manufacturer and model.startswith("Raspberry Pi"):
            manufacturer = "Raspberry Pi"
        if not manufacturer or not model:
            print(f"  WARN no manufacturer/productname grains ({manufacturer!r}, {model!r}), skipped")
            counts["warn"] += 1
            continue

        obj = nb.one("dcim/devices", name__ie=minion)
        if obj and obj["name"] != minion:
            print(f"  WARN NetBox device is named {obj['name']!r}; ext_pillar needs {minion!r}. Rename it")
            counts["warn"] += 1
        site_id = ensure_named(nb, "dcim/sites", site, "site", status="active")
        if obj and (obj.get("site") or {}).get("id") != site_id:
            counts["changed"] += 1
            nb.update("dcim/devices", obj["id"], {"site": site_id}, f"device {minion} site -> {site}")
        if not obj:
            counts["changed"] += 1
            obj = nb.create("dcim/devices", {
                "name": minion,
                "site": site_id,
                "role": ensure_named(nb, "dcim/device-roles", role, "role"),
                "device_type": ensure_device_type(nb, manufacturer, model),
                "status": "active",
            }, f"device {minion} ({site}, {role}, {manufacturer} {model})")
        sync_host(nb, args, minion, host, ifaces.get(minion, {}), obj, "device", tag_id, counts)

    if args.appliances:
        role_id = ensure_named(nb, "dcim/device-roles", APPLIANCE_ROLE, "role", vm_role=True)
        for name, cidr in sorted(APPLIANCES.items()):
            print(f"{name} (appliance)")
            obj = nb.one("virtualization/virtual-machines", name__ie=name)
            if not obj:
                counts["changed"] += 1
                obj = nb.create("virtualization/virtual-machines",
                                {"name": name, "cluster": cluster_id, "role": role_id, "status": "active"},
                                f"VM {name}")
            elif not obj.get("role"):
                counts["changed"] += 1
                nb.update("virtualization/virtual-machines", obj["id"], {"role": role_id}, f"VM {name} role")
            iface = ipaddress.ip_interface(cidr)
            fake = {"eth0": {"inet": [{"address": str(iface.ip), "netmask": str(iface.netmask)}]}}
            sync_host(nb, args, name, name, fake, obj, "vm", tag_id, counts)

    print(f"\nDone: {counts['changed']} changes {'made' if args.apply else 'planned'}, "
          f"{counts['warn']} warnings, {counts['skipped']} physical skipped")
    return 1 if counts["warn"] else 0


if __name__ == "__main__":
    sys.exit(main())
