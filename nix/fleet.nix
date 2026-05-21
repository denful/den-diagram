# Fleet-level graph construction from a host registry.
#
# Produces a compact record describing all hosts/users in a den flake,
# suitable for rendering as a C4 Context diagram. Unlike per-host tracing
# (den's capture.nix), this iterates a host registry and does not resolve
# aspects per-host.
#
# providerSubAspects is optional — callers that want provider data in
# treemap views must pre-compute it via den.lib.capture and pass it in.
#
# Output shape:
#
#   { flakeName, hosts, users, relations, providerSubAspects }
#     where:
#       hosts     = [ { name, description } ]
#       users     = [ { name } ]
#       relations = [ { from, to, label } ]   # user->host (class) edges
{ lib }:
let

  # Flatten a `den.hosts`-shaped attrset to a list of
  # { name, system, host, users : [ { name, classes } ] }.
  flattenHosts =
    hostsAttr:
    lib.concatMap (
      system:
      lib.mapAttrsToList (hostName: hostObj: {
        name = hostName;
        inherit system;
        host = hostObj;
        users = lib.mapAttrsToList (userName: user: {
          name = userName;
          classes = user.classes or [ ];
        }) (hostObj.users or { });
      }) (hostsAttr.${system} or { })
    ) (builtins.attrNames hostsAttr);

  fleetGraph =
    {
      hosts,
      flakeName ? "den flake",
      providerSubAspects ? [ ],
    }:
    let
      allHosts = flattenHosts hosts;

      hostRecords = map (h: {
        inherit (h) name;
        description = h.system;
      }) allHosts;

      users = lib.unique (lib.concatMap (h: map (u: { inherit (u) name; }) h.users) allHosts);

      relations = lib.concatMap (
        h:
        map (u: {
          from = u.name;
          to = h.name;
          label = if u.classes == [ ] then "uses" else lib.concatStringsSep "+" u.classes;
        }) h.users
      ) allHosts;
    in
    {
      inherit flakeName relations providerSubAspects;
      hosts = hostRecords;
      inherit users;
    };
in
{
  inherit fleetGraph flattenHosts;
}
