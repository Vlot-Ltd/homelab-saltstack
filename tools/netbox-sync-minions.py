#!/opt/saltstack/salt/bin/python3
"""Register Salt minions in NetBox as VMs, with their LAN and Tailscale IPs.

Run on the Salt master as root, with onedir's Python (it has salt and requests):

    /opt/saltstack/salt/bin/python3 tools/netbox-sync-minions.py            # dry run
    /opt/saltstack/salt/bin/python3 tools/netbox-sync-minions.py --apply    # write

- NetBox VM name = Salt minion ID, which is what the NetBox ext_pillar matches on.
- Existing IP address objects are reused (matched on host address, any mask), never
  duplicated. An IP already assigned to something else is reported, not moved.
- Tailscale IPs (100.64.0.0/10) get the `tailscale` tag and a <host>.<tailnet> DNS
  name. The VM's primary IPv4 is its first LAN address.
- Physical minions are skipped: they're Devices in NetBox, do those by hand.
- The API token is read from NETBOX_TOKEN or prompted for; it's never stored.

Safe to re-run: anything already correct is left alone.
"""

import argparse
import getpass
import ipaddress
import os
import sys

import requests
import salt.client

KEEP_IFACES = ("eth", "ens", "enp", "eno", "wlan", "wlp", "tailscale")
TAILNET_RANGE = ipaddress.ip_network("100.64.0.0/10")
VMINTERFACE = "virtualization.vminterface"


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


def sync_ip(nb, minion, iface, addr, dns_name, tag_id, counts):
    """Create or attach one IP. Returns its NetBox id (None in a dry run)."""
    host = addr["address"]
    cidr = f"{host}/{prefixlen(addr['netmask'])}"
    label = f"{minion} {iface['name']} {cidr}"
    want = {
        "assigned_object_type": VMINTERFACE,
        "assigned_object_id": iface["id"],
        "dns_name": dns_name,
    }

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
    if owner_id and (owner_type != VMINTERFACE or (iface["id"] and owner_id != iface["id"])):
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


def main():
    ap = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    ap.add_argument("--apply", action="store_true", help="write to NetBox (default: dry run)")
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
    grains = local.cmd(args.target, "grains.item", ["virtual", "host"], timeout=30)
    ifaces = local.cmd(args.target, "network.interfaces", timeout=30)
    print(f"{len(grains)} minions answered\n")

    cluster_id = ensure_cluster(nb, args.cluster)
    tag_id = ensure_tag(nb, "tailscale")
    counts = {"changed": 0, "warn": 0, "skipped": 0}

    for minion in sorted(grains):
        print(f"{minion}")
        if grains[minion].get("virtual") == "physical":
            print("  SKIP physical: add it as a Device by hand")
            counts["skipped"] += 1
            continue
        host = grains[minion].get("host") or minion

        vm = nb.one("virtualization/virtual-machines", name__ie=minion)
        if vm and vm["name"] != minion:
            print(f"  WARN NetBox VM is named {vm['name']!r}; ext_pillar needs {minion!r}. Rename it")
            counts["warn"] += 1
        if not vm:
            counts["changed"] += 1
            vm = nb.create(
                "virtualization/virtual-machines",
                {"name": minion, "cluster": cluster_id, "status": "active"},
                f"VM {minion}",
            )

        primary = None
        for name, data in sorted(ifaces.get(minion, {}).items()):
            addrs = data.get("inet") or []
            if not name.startswith(KEEP_IFACES) or not addrs:
                continue
            iface = vm["id"] and nb.one("virtualization/interfaces", virtual_machine_id=vm["id"], name=name)
            if not iface:
                counts["changed"] += 1
                iface = nb.create(
                    "virtualization/interfaces",
                    {"virtual_machine": vm["id"], "name": name},
                    f"{minion} interface {name}",
                )
            for addr in addrs:
                is_ts = ipaddress.ip_address(addr["address"]) in TAILNET_RANGE
                dns = f"{host}.{args.tailnet}" if is_ts else host
                ip_id = sync_ip(nb, minion, iface, addr, dns, tag_id if is_ts else None, counts)
                # A skipped IP (conflict, duplicates) returns None even when applying;
                # never let that clear the VM's primary IP.
                if not is_ts and primary is None and (ip_id or not args.apply):
                    primary = (ip_id, addr["address"])

        current = (vm.get("primary_ip4") or {}).get("id")
        if primary and (primary[0] is None or current != primary[0]):
            counts["changed"] += 1
            nb.update("virtualization/virtual-machines", vm["id"], {"primary_ip4": primary[0]},
                      f"VM {minion} primary IPv4 -> {primary[1]}")

    print(f"\nDone: {counts['changed']} changes {'made' if args.apply else 'planned'}, "
          f"{counts['warn']} warnings, {counts['skipped']} physical skipped")
    return 1 if counts["warn"] else 0


if __name__ == "__main__":
    sys.exit(main())
