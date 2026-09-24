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

  lines = s: lib.splitString "\n" s;
  hasLine = l: s: builtins.elem l (lines s);
  countLines = pred: s: builtins.length (builtins.filter pred (lines s));

  # WCAG 2.x relative luminance / contrast ratio. Nix has no float pow, so
  # x^0.4 is solved by Newton's method on y^5 = x^2.
  contrast =
    let
      hexVal =
        s:
        lib.foldl' (
          acc: c:
          acc * 16 + lib.lists.findFirstIndex (d: d == c) 0 (lib.stringToCharacters "0123456789abcdef")
        ) 0 (lib.stringToCharacters (lib.toLower s));
      root5 =
        x: lib.foldl' (y: _: y - (y * y * y * y * y - x) / (5.0 * y * y * y * y)) 1.0 (lib.range 1 40);
      linear =
        c8:
        let
          c = c8 / 255.0;
          b = (c + 5.5e-2) / 1.055;
        in
        if c <= 4.045e-2 then c / 12.92 else b * b * root5 (b * b);
      channel = hex: i: linear (hexVal (builtins.substring (1 + 2 * i) 2 hex) * 1.0);
      luminance = hex: 0.2126 * channel hex 0 + 0.7152 * channel hex 1 + 7.22e-2 * channel hex 2;
    in
    a: b:
    let
      la = luminance a;
      lb = luminance b;
    in
    (lib.max la lb + 5.0e-2) / (lib.min la lb + 5.0e-2);

  # A devbox-shaped trace: an organizer role with no class content of its
  # own, and a parametric aspect whose class content is traced on its
  # `host/resolve(<name>)` child rather than on the aspect itself.
  devboxEntries = [
    (mkEntry {
      name = "devbox";
      class = "nixos";
      hasClass = true;
    })
    (mkEntry {
      name = "workstation";
      parent = "devbox";
      class = "nixos";
    })
    (mkEntry {
      name = "desktop";
      parent = "workstation";
      class = "nixos";
      hasClass = true;
    })
    (mkEntry {
      name = "server";
      parent = "devbox";
      class = "nixos";
      hasClass = true;
    })
    (mkEntry {
      name = "backup";
      parent = "server";
      class = "nixos";
    })
    (mkEntry {
      name = "host/resolve(backup)";
      parent = "backup";
      class = "nixos";
      hasClass = true;
      isParametric = true;
      fnArgNames = [ "host" ];
    })
    # An entity root resolves itself; that is not a parametric aspect.
    (mkEntry {
      name = "user";
      parent = "devbox";
      class = "nixos";
    })
    (mkEntry {
      name = "user/resolve(user)";
      parent = "user";
      class = "nixos";
      hasClass = true;
    })
    (mkEntry {
      name = "os-to-host";
      isPolicyDispatch = true;
      policyName = "os-to-host";
      from = "host";
    })
  ];
  devbox = diagram.graph.build {
    entries = devboxEntries;
    rootName = "devbox";
  };
  nodeByLabel = g: label: lib.findFirst (n: n.label == label) null g.nodes;
  hasEdge =
    g: from: to:
    builtins.any (e: e.from == from && e.to == to) g.edges;

  # Fleet capture shaped like fleet-demo: flake -> fleet -> environment ->
  # host -> user, plus the per-system scope den always creates. ctxTrace is
  # in the pipeline's emission order, which is not root-to-leaf.
  fleetCapture = {
    entries = [
      (mkEntry {
        name = "env-users";
        isPolicyDispatch = true;
        policyName = "env-users";
        from = "host";
      })
      (mkEntry {
        name = "collect-backends";
        isPolicyDispatch = true;
        policyName = "collect-backends";
        from = "host";
      })
    ];
    scopeParent = {
      "system=x86_64-linux" = "__unscoped";
      "fleet=fleet" = "__unscoped";
      "environment=prod,fleet=fleet" = "fleet=fleet";
      "environment=prod,fleet=fleet,host=lb" = "environment=prod,fleet=fleet";
      "environment=prod,fleet=fleet,host=web" = "environment=prod,fleet=fleet";
      "environment=prod,fleet=fleet,host=lb,user=alice" = "environment=prod,fleet=fleet,host=lb";
      "environment=prod,fleet=fleet,host=web,user=alice" = "environment=prod,fleet=fleet,host=web";
      "environment=prod,fleet=fleet,host=web,user=bob" = "environment=prod,fleet=fleet,host=web";
    };
    scopeEntityKind = {
      "system=x86_64-linux" = "flake-system";
      "fleet=fleet" = "fleet";
      "environment=prod,fleet=fleet" = "environment";
      "environment=prod,fleet=fleet,host=lb" = "host";
      "environment=prod,fleet=fleet,host=web" = "host";
      "environment=prod,fleet=fleet,host=lb,user=alice" = "user";
      "environment=prod,fleet=fleet,host=web,user=alice" = "user";
      "environment=prod,fleet=fleet,host=web,user=bob" = "user";
    };
    scopeSourcePolicy = {
      "system=x86_64-linux" = "flake-to-systems";
      "fleet=fleet" = "to-fleet";
      "environment=prod,fleet=fleet" = "fleet-to-envs";
      "environment=prod,fleet=fleet,host=lb" = "env-to-hosts";
      "environment=prod,fleet=fleet,host=web" = "env-to-hosts";
      "environment=prod,fleet=fleet,host=lb,user=alice" = "env-users";
      "environment=prod,fleet=fleet,host=web,user=alice" = "env-users";
      "environment=prod,fleet=fleet,host=web,user=bob" = "env-users";
    };
    scopedPipeEffects = { };
    scopedClassImports = { };
    ctxTrace = map (k: { key = k; }) [
      "flake-system"
      "environment"
      "host"
      "user"
      "fleet"
      "flake"
    ];
  };
in
{
  doc-review = {
    # A parametric aspect contributes class content through its resolve
    # child; the slice must keep it and draw it as parametric.
    test-class-slice-keeps-parametric-aspect =
      let
        backup = nodeByLabel (diagram.graph.classSlice "nixos" devbox) "backup";
      in
      {
        expr = {
          kept = backup != null;
          shape = backup.shape or null;
          aspectsShape = (nodeByLabel (diagram.graph.aspectsOnly devbox) "backup").shape;
          entityRoot = (nodeByLabel devbox "user").hasClass;
        };
        expected = {
          kept = true;
          shape = "hexagon";
          aspectsShape = "hexagon";
          entityRoot = false;
        };
      };

    # An organizer aspect (includes only) is still user-declared.
    test-user-declared-keeps-organizer =
      let
        g = diagram.graph.userDeclaredOnly (diagram.graph.aspectsOnly devbox);
      in
      {
        expr = {
          workstation = nodeByLabel g "workstation" != null;
          inEdge = hasEdge g "devbox" "workstation";
          outEdge = hasEdge g "workstation" "desktop";
          policyDropped = nodeByLabel g "os-to-host" == null;
        };
        expected = {
          workstation = true;
          inEdge = true;
          outEdge = true;
          policyDropped = true;
        };
      };

    # WCAG AA (4.5:1) for every fill the default theme puts text on.
    test-default-theme-contrast =
      let
        t = diagram.defaultTheme;
        pairs =
          map (fill: {
            inherit fill;
            text = t.rootText;
          }) t.accentPool
          ++ [
            {
              fill = t.rootFill;
              text = t.rootText;
            }
            {
              fill = t.excludedFill;
              text = t.excludedText;
            }
            {
              fill = t.replacedFill;
              text = t.replacedText;
            }
            {
              fill = t.nodeBg;
              text = t.nodeText;
            }
            {
              fill = t.clusterBg;
              text = t.foreground;
            }
          ];
      in
      {
        expr = map (p: "${p.fill} on ${p.text}") (builtins.filter (p: contrast p.fill p.text < 4.5) pairs);
        expected = [ ];
      };

    # Without environments, hosts hang straight off the per-system scope;
    # the fleet DAG must still draw them.
    test-fleet-dag-without-environments =
      let
        out = diagram.toFleetDagMermaid {
          fleetCapture = {
            scopeParent = {
              "system=x" = "__unscoped";
              "host=laptop,system=x" = "system=x";
            };
            scopeEntityKind = {
              "system=x" = "flake-system";
              "host=laptop,system=x" = "host";
            };
            scopedPipeEffects = { };
            scopedClassImports = { };
          };
          hostGraphs.laptop = diagram.graph.build {
            entries = [
              (mkEntry {
                name = "laptop";
                class = "nixos";
                hasClass = true;
              })
            ];
            rootName = "laptop";
          };
        };
      in
      {
        expr = {
          subgraph = hasLine "    subgraph host_laptop[\"laptop\"]" out;
          node = hasLine "      laptop__laptop[\"laptop\"]" out;
        };
        expected = {
          subgraph = true;
          node = true;
        };
      };

    # The same policy firing in two scopes is one participant.
    test-policy-sequence-unique-participants =
      let
        g = diagram.graph.build {
          entries = [
            (mkEntry { name = "laptop"; })
            (mkEntry {
              name = "os-to-host";
              isPolicyDispatch = true;
              policyName = "os-to-host";
              from = "host";
              entityInstance = "host:laptop";
            })
            (mkEntry {
              name = "os-to-host";
              isPolicyDispatch = true;
              policyName = "os-to-host";
              from = "user";
              entityInstance = "user:alice";
            })
          ];
          rootName = "laptop";
        };
      in
      {
        expr = countLines (lib.hasPrefix "    participant os_to_host ") (diagram.toPolicySequenceMermaid g);
        expected = 1;
      };

    test-fleet-summary-chain-and-users =
      let
        out = diagram.text.fleetSummary fleetCapture;
      in
      {
        expr = {
          chain = hasLine "- Scope chain: flake → flake-system; flake → fleet → environment → host → user" out;
          counts = hasLine "- **1** environments, **2** hosts, **2** users" out;
          envRow = hasLine "| prod | lb, web | 2 | 2 |" out;
        };
        expected = {
          chain = true;
          counts = true;
          envRow = true;
        };
      };

    # An edge is labelled with the policy that created the child scope, not
    # with every policy that fired at the parent.
    test-policy-map-labels-creating-policy =
      let
        out = diagram.toPolicyResolutionMapMermaid fleetCapture;
      in
      {
        expr = {
          userEdge = hasLine "  environment_prod_fleet_fleet_host_web -->|env-users| environment_prod_fleet_fleet_host_web_user_bob" out;
          otherPolicy = lib.hasInfix "collect-backends" out;
        };
        expected = {
          userEdge = true;
          otherPolicy = false;
        };
      };

  };

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

    # The SAME graph from den's post-rename spelling of the provenance chain.
    # den renamed the field `provider` -> `aspect-chain` (denful/den#678), and
    # the two never coexist in one den, so both spellings must build the same
    # node. Paired with test-provider-entries above, which is the identical
    # fixture under the old name: together they pin the compat in BOTH
    # directions, and a regression breaks exactly one of the pair.
    test-aspect-chain-entries =
      let
        entries = [
          (mkEntry {
            name = "root";
            class = "nixos";
            hasClass = true;
          })
          # `provider` REMOVED, not merely overridden: post-rename den emits no
          # such key, and its absence is what made graph.nix abort with
          # `attribute 'provider' missing`. An entry carrying both names would
          # pass on the preferred arm without ever exercising that.
          (
            builtins.removeAttrs (mkEntry {
              name = "sub";
              parent = "root";
              class = "nixos";
              hasClass = true;
            }) [ "provider" ]
            // {
              "aspect-chain" = [ "root" ];
            }
          )
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

    # A chainless entry gains NO path segments. Without this, both cells above
    # would also pass for a reader that ignored the chain entirely and let the
    # `or [ ]` fallback stand in for it — which is the silent half of the
    # rename break.
    test-no-chain-keeps-bare-id =
      let
        g = diagram.graph.build {
          entries = [
            (mkEntry {
              name = "solo";
              class = "nixos";
              hasClass = true;
            })
          ];
          rootName = "solo";
        };
        node = lib.findFirst (n: n.label == "solo") null g.nodes;
      in
      {
        expr = {
          id = node.id;
          inherit (node) providerPath;
        };
        expected = {
          id = "solo";
          providerPath = [ ];
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
