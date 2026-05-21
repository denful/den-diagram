# den-diagram standalone tests.
#
# Feed pre-built trace entries to diagram functions and verify output.
# No den dependency — tests exercise the library in isolation.
{ lib, diagram }:
let
  # Minimal trace entry matching the shape buildGraph / mkNode reads.
  # Fields mirror graph.nix's stubEntry plus the extras mkNode accesses.
  mkEntry =
    {
      name,
      parent ? null,
      class ? "",
      provider ? [ ],
      excluded ? false,
      excludedFrom ? null,
      replacedBy ? null,
      isProvider ? false,
      handlers ? [ ],
      hasAdapter ? false,
      hasClass ? false,
      isParametric ? false,
      fnArgNames ? [ ],
      entityKind ? null,
      entityInstance ? null,
      isPolicyDispatch ? false,
      policyName ? null,
      from ? null,
      to ? null,
    }:
    {
      inherit
        name
        parent
        class
        provider
        excluded
        excludedFrom
        replacedBy
        isProvider
        handlers
        hasAdapter
        hasClass
        isParametric
        fnArgNames
        entityKind
        entityInstance
        isPolicyDispatch
        policyName
        from
        to
        ;
    };
in
{
  context = {
    # diagram.context builds a graph IR from trace entries
    test-basic-context =
      let
        entries = [
          (mkEntry {
            name = "child";
            parent = "root";
            class = "nixos";
            hasClass = true;
          })
          (mkEntry { name = "root"; })
        ];
        graph = diagram.context {
          inherit entries;
          name = "testhost";
        };
      in
      {
        expr = {
          hasNodes = graph.nodes != [ ];
          hasEdges = graph ? edges;
          inherit (graph) rootName;
        };
        expected = {
          hasNodes = true;
          hasEdges = true;
          rootName = "testhost";
        };
      };

    # context handles excluded entries
    test-context-with-excluded =
      let
        entries = [
          (mkEntry {
            name = "networking";
            parent = "testhost";
            class = "nixos";
            hasClass = true;
          })
          (mkEntry {
            name = "desktop";
            parent = "testhost";
            class = "nixos";
            hasClass = true;
          })
          (mkEntry {
            name = "tailscale";
            parent = "testhost";
            class = "nixos";
            hasClass = true;
            excluded = true;
            handlers = [ { type = "exclude"; } ];
          })
          (mkEntry {
            name = "testhost";
            handlers = [ { type = "exclude"; } ];
          })
        ];
        graph = diagram.context {
          inherit entries;
          name = "testhost";
        };
        excludedNodes = builtins.filter (n: n.isExcluded) graph.nodes;
        activeNodes = builtins.filter (n: !n.isExcluded) graph.nodes;
      in
      {
        expr = {
          totalNodes = builtins.length graph.nodes;
          excludedCount = builtins.length excludedNodes;
          activeCount = builtins.length activeNodes;
        };
        expected = {
          totalNodes = 4;
          excludedCount = 1;
          activeCount = 3;
        };
      };

    # context preserves pathsByClass passthrough
    test-context-paths-by-class =
      let
        entries = [
          (mkEntry {
            name = "root";
            class = "nixos";
            hasClass = true;
          })
        ];
        pbc = {
          nixos = [ [ "root" ] ];
        };
        graph = diagram.context {
          inherit entries;
          name = "root";
          pathsByClass = pbc;
        };
      in
      {
        expr = graph.pathsByClass;
        expected = pbc;
      };
  };

  graph = {
    # graph.build produces nodes and edges
    test-build-graph =
      let
        entries = [
          (mkEntry {
            name = "root";
            class = "nixos";
            hasClass = true;
          })
        ];
        g = diagram.graph.build {
          inherit entries;
          rootName = "root";
        };
      in
      {
        expr = {
          hasNodes = g.nodes != [ ];
          inherit (g) rootName;
          inherit (g) rootId;
        };
        expected = {
          hasNodes = true;
          rootName = "root";
          rootId = "root";
        };
      };

    # edges connect parent to child
    test-build-graph-edges =
      let
        entries = [
          (mkEntry { name = "root"; })
          (mkEntry {
            name = "child";
            parent = "root";
            class = "nixos";
            hasClass = true;
          })
        ];
        g = diagram.graph.build {
          inherit entries;
          rootName = "root";
        };
        edge = builtins.head g.edges;
      in
      {
        expr = {
          edgeCount = builtins.length g.edges;
          inherit (edge) from;
          inherit (edge) to;
        };
        expected = {
          edgeCount = 1;
          from = "root";
          to = "child";
        };
      };

    # provider entries get path-based IDs
    test-provider-entries =
      let
        entries = [
          (mkEntry {
            name = "root";
            class = "nixos";
            hasClass = true;
          })
          (mkEntry {
            name = "sub";
            parent = "root";
            provider = [ "root" ];
            class = "nixos";
            hasClass = true;
          })
        ];
        g = diagram.graph.build {
          inherit entries;
          rootName = "root";
        };
        subNode = lib.findFirst (n: n.label == "root/sub") null g.nodes;
      in
      {
        expr = {
          hasSubNode = subNode != null;
          subId = subNode.id;
          inherit (subNode) providerPath;
        };
        expected = {
          hasSubNode = true;
          subId = "root__sub";
          providerPath = [ "root" ];
        };
      };

    # excluded nodes don't generate outbound edges
    test-excluded-edge-suppression =
      let
        entries = [
          (mkEntry { name = "root"; })
          (mkEntry {
            name = "excluded-parent";
            parent = "root";
            excluded = true;
          })
          (mkEntry {
            name = "child-of-excluded";
            parent = "excluded-parent";
          })
        ];
        g = diagram.graph.build {
          inherit entries;
          rootName = "root";
        };
        # Edge from excluded-parent to root should exist (excluded-parent not source of edge),
        # but edge from child-of-excluded to excluded-parent should be dropped
        # because excluded-parent is in excludedIds.
        edgeTargets = map (e: e.to) g.edges;
      in
      {
        expr = {
          # child-of-excluded should not have an edge because its parent is excluded
          childHasEdge = builtins.any (t: t == "n_child_of_excluded") edgeTargets;
        };
        expected = {
          childHasEdge = false;
        };
      };
  };

  fleet = {
    # fleet.of builds fleet data from host registry
    test-fleet-graph =
      let
        hosts = {
          x86_64-linux = {
            web1 = {
              name = "web1";
              users = {
                alice = {
                  name = "alice";
                  classes = [ "homeManager" ];
                };
              };
            };
            web2 = {
              name = "web2";
              users = { };
            };
          };
        };
        result = diagram.fleet.of {
          inherit hosts;
          flakeName = "test-fleet";
        };
      in
      {
        expr = {
          hostCount = builtins.length result.hosts;
          userCount = builtins.length result.users;
          hasRelations = result.relations != [ ];
          inherit (result) flakeName;
        };
        expected = {
          hostCount = 2;
          userCount = 1;
          hasRelations = true;
          flakeName = "test-fleet";
        };
      };

    # fleet relations carry class labels
    test-fleet-relations =
      let
        hosts = {
          x86_64-linux = {
            myhost = {
              name = "myhost";
              users = {
                bob = {
                  name = "bob";
                  classes = [
                    "homeManager"
                    "nixos"
                  ];
                };
              };
            };
          };
        };
        result = diagram.fleet.of {
          inherit hosts;
          flakeName = "labels";
        };
        rel = builtins.head result.relations;
      in
      {
        expr = {
          inherit (rel) from;
          inherit (rel) to;
          inherit (rel) label;
        };
        expected = {
          from = "bob";
          to = "myhost";
          label = "homeManager+nixos";
        };
      };

    # fleet with no users produces empty relations
    test-fleet-no-users =
      let
        hosts = {
          aarch64-darwin = {
            mac1 = {
              name = "mac1";
              users = { };
            };
          };
        };
        result = diagram.fleet.of {
          inherit hosts;
          flakeName = "no-users";
        };
      in
      {
        expr = {
          hostCount = builtins.length result.hosts;
          userCount = builtins.length result.users;
          relationCount = builtins.length result.relations;
        };
        expected = {
          hostCount = 1;
          userCount = 0;
          relationCount = 0;
        };
      };
  };

  namespace = {
    # ofNamespace builds a graph from aspect declarations
    test-namespace-graph =
      let
        aspects = {
          networking = {
            name = "networking";
            meta = { };
            includes = [ ];
          };
          desktop = {
            name = "desktop";
            meta = { };
            includes = [ { name = "networking"; } ];
          };
        };
        g = diagram.graph.ofNamespace {
          inherit aspects;
        };
      in
      {
        expr = {
          hasNodes = g.nodes != [ ];
          hasEdges = g.edges != [ ];
          inherit (g) rootName;
        };
        expected = {
          hasNodes = true;
          hasEdges = true;
          rootName = "aspects";
        };
      };

    # namespace graph filters aspects
    test-namespace-filter =
      let
        aspects = {
          keep = {
            name = "keep";
            meta = { };
            includes = [ ];
          };
          drop = {
            name = "drop";
            meta = { };
            includes = [ ];
          };
        };
        g = diagram.graph.ofNamespace {
          inherit aspects;
          filter = v: v.name == "keep";
        };
      in
      {
        expr = builtins.length g.nodes;
        expected = 1;
      };

    # namespace detects include edges
    test-namespace-include-edges =
      let
        aspects = {
          a = {
            name = "a";
            meta = { };
            includes = [ ];
          };
          b = {
            name = "b";
            meta = { };
            includes = [ { name = "a"; } ];
          };
          c = {
            name = "c";
            meta = { };
            includes = [
              { name = "a"; }
              { name = "b"; }
            ];
          };
        };
        g = diagram.graph.ofNamespace {
          inherit aspects;
        };
        # Edges: root->c (not included by anyone), b->a, c->a, c->b
        declEdges = builtins.filter (e: e.from != g.rootId) g.edges;
      in
      {
        expr = builtins.length declEdges;
        expected = 3;
      };
  };
}
