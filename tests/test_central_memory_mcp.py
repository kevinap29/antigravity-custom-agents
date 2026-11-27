import importlib.util
import json
import sys
import tempfile
import types
import unittest
from pathlib import Path
from unittest import mock

REPO_ROOT = Path(__file__).resolve().parent.parent
MCP_DIR = REPO_ROOT / "mcp"


def _ensure_mcp_dependency_stubs() -> None:
    """Install minimal module stubs when fastembed/fastmcp/qdrant_client are absent in CI."""
    if importlib.util.find_spec("fastembed") is None and "fastembed" not in sys.modules:
        fastembed_mod = types.ModuleType("fastembed")

        class _StubTextEmbedding:
            def __init__(self, model_name: str = "") -> None:
                self.model_name = model_name

            def embed(self, texts):
                return [[0.0] * 384 for _ in texts]

        fastembed_mod.TextEmbedding = _StubTextEmbedding
        sys.modules["fastembed"] = fastembed_mod

    if importlib.util.find_spec("fastmcp") is None and "fastmcp" not in sys.modules:
        fastmcp_mod = types.ModuleType("fastmcp")

        class _StubFastMCP:
            def __init__(self, name: str = "") -> None:
                self.name = name

            def tool(self, fn=None, **_kwargs):
                if fn is not None:
                    return fn
                return lambda f: f

            def run(self) -> None:
                return None

        fastmcp_mod.FastMCP = _StubFastMCP
        sys.modules["fastmcp"] = fastmcp_mod

    if importlib.util.find_spec("qdrant_client") is None and "qdrant_client" not in sys.modules:
        qdrant_mod = types.ModuleType("qdrant_client")
        models_mod = types.ModuleType("qdrant_client.models")

        class _StubQdrantClient:
            def __init__(self, *args, **kwargs) -> None:
                pass

        class _StubDataClass:
            def __init__(self, *args, **kwargs) -> None:
                for k, v in kwargs.items():
                    setattr(self, k, v)

        class _StubDistance:
            COSINE = "Cosine"

        class _StubPayloadSchemaType:
            KEYWORD = "keyword"

        qdrant_mod.QdrantClient = _StubQdrantClient
        qdrant_mod.models = models_mod

        models_mod.Distance = _StubDistance
        models_mod.PayloadSchemaType = _StubPayloadSchemaType
        models_mod.FieldCondition = _StubDataClass
        models_mod.Filter = _StubDataClass
        models_mod.MatchAny = _StubDataClass
        models_mod.MatchValue = _StubDataClass
        models_mod.PointStruct = _StubDataClass
        models_mod.VectorParams = _StubDataClass

        sys.modules["qdrant_client"] = qdrant_mod
        sys.modules["qdrant_client.models"] = models_mod


_ensure_mcp_dependency_stubs()
if str(MCP_DIR) not in sys.path:
    sys.path.insert(0, str(MCP_DIR))

import central_memory_mcp  # noqa: E402


def _unwrap_tool(func_or_tool):
    """Return underlying Python callable whether or not FastMCP wrapped it."""
    return getattr(func_or_tool, "fn", func_or_tool)


class CentralMemoryMcpTests(unittest.TestCase):
    def test_require_writer_allows_expected_roles(self) -> None:
        for role in ("antigravity", "hermes"):
            with self.subTest(role=role):
                with mock.patch.object(central_memory_mcp, "AGENT_ROLE", role):
                    central_memory_mcp._require_writer()

    def test_require_writer_denies_untrusted_roles(self) -> None:
        for role in ("readonly", "guest", ""):
            with self.subTest(role=role):
                with mock.patch.object(central_memory_mcp, "AGENT_ROLE", role):
                    with self.assertRaises(PermissionError):
                        central_memory_mcp._require_writer()

    def test_memory_get_rules_scopes_and_missing_files(self) -> None:
        get_rules = _unwrap_tool(central_memory_mcp.memory_get_rules)

        with tempfile.TemporaryDirectory() as tmp:
            mem_dir = Path(tmp)
            (mem_dir / "GLOBAL_RULES.md").write_text("# Global\nrule-1", encoding="utf-8")
            (mem_dir / "ARCHITECTURE_NOTES.md").write_text("# Arch\nnote-1", encoding="utf-8")

            with mock.patch.object(central_memory_mcp, "MEMORY_DIR", mem_dir), mock.patch.object(
                central_memory_mcp, "AGENT_ROLE", "antigravity"
            ):
                res_global = get_rules("global")
                self.assertEqual(res_global["role"], "antigravity")
                self.assertEqual(res_global["rules"], {"global": "# Global\nrule-1"})

                res_arch = get_rules("architecture")
                self.assertEqual(res_arch["rules"], {"architecture": "# Arch\nnote-1"})

                res_all = get_rules("all")
                self.assertEqual(
                    res_all["rules"],
                    {
                        "global": "# Global\nrule-1",
                        "architecture": "# Arch\nnote-1",
                    },
                )

                # Missing file returns empty string gracefully
                (mem_dir / "ARCHITECTURE_NOTES.md").unlink()
                res_missing = get_rules("all")
                self.assertEqual(res_missing["rules"]["global"], "# Global\nrule-1")
                self.assertEqual(res_missing["rules"]["architecture"], "")

    def test_blueprint_fingerprint_ignores_non_structural_edits_and_detects_manifest_or_dir_changes(
        self,
    ) -> None:
        base_tree = "\n".join(
            [
                "100644 blob aaa111\tREADME.md",
                "100644 blob bbb111\tpackage.json",
                "100644 blob ccc111\tsrc/app.ts",
                "100644 blob ddd111\tsrc/api/routes/users.ts",
                "100644 blob eee111\tsrc/Api/Api.csproj",
            ]
        )
        non_structural_edit = "\n".join(
            [
                "100644 blob aaa999\tREADME.md",
                "100644 blob bbb111\tpackage.json",
                "100644 blob ccc999\tsrc/app.ts",
                "100644 blob ddd111\tsrc/api/routes/users.ts",
                "100644 blob fff222\tsrc/api/routes/orders.ts",
                "100644 blob eee111\tsrc/Api/Api.csproj",
            ]
        )
        manifest_package_edit = base_tree.replace("bbb111\tpackage.json", "bbb999\tpackage.json")
        manifest_csproj_edit = base_tree.replace("eee111\tsrc/Api/Api.csproj", "eee999\tsrc/Api/Api.csproj")
        new_depth2_dir = base_tree + "\n100644 blob ggg111\tsrc/billing/service.ts"
        new_depth1_dir = base_tree + "\n100644 blob hhh111\tdocs/guide.md"

        def _fp_for(stdout: str) -> str | None:
            completed = types.SimpleNamespace(returncode=0, stdout=stdout)
            with mock.patch.object(central_memory_mcp.subprocess, "run", return_value=completed):
                return central_memory_mcp._blueprint_fingerprint("/repo")

        fp_base = _fp_for(base_tree)
        self.assertIsNotNone(fp_base)
        self.assertTrue(fp_base.startswith("struct:"))
        self.assertEqual(len(fp_base), len("struct:") + 16)

        self.assertEqual(_fp_for(non_structural_edit), fp_base)
        self.assertNotEqual(_fp_for(manifest_package_edit), fp_base)
        self.assertNotEqual(_fp_for(manifest_csproj_edit), fp_base)
        self.assertNotEqual(_fp_for(new_depth2_dir), fp_base)
        self.assertNotEqual(_fp_for(new_depth1_dir), fp_base)

    def test_blueprint_fingerprint_subdir_scoping_and_error_handling(self) -> None:
        self.assertIsNone(central_memory_mcp._blueprint_fingerprint(""))

        fail_res = types.SimpleNamespace(returncode=128, stdout="")
        with mock.patch.object(central_memory_mcp.subprocess, "run", return_value=fail_res):
            self.assertIsNone(central_memory_mcp._blueprint_fingerprint("/not-a-repo"))

        # Nonexistent subdir returns empty ls-tree stdout with exit 0 -> must return None
        empty_res = types.SimpleNamespace(returncode=0, stdout="   \n")
        with mock.patch.object(central_memory_mcp.subprocess, "run", return_value=empty_res):
            self.assertIsNone(central_memory_mcp._blueprint_fingerprint("/repo", subdir="missing/dir"))

        scoped_stdout = "\n".join(
            [
                "100644 blob 111aaa\tservices/api/package.json",
                "100644 blob 222bbb\tservices/api/src/routes/health.ts",
            ]
        )
        ok_res = types.SimpleNamespace(returncode=0, stdout=scoped_stdout)
        for variant in ("services/api/", r"services\api", "./services/api", r".\services\api\\"):
            with self.subTest(subdir=variant):
                with mock.patch.object(
                    central_memory_mcp.subprocess, "run", return_value=ok_res
                ) as run_mock:
                    fp_scoped = central_memory_mcp._blueprint_fingerprint("/repo", subdir=variant)

                self.assertEqual(
                    run_mock.call_args.args[0],
                    ["git", "-C", "/repo", "ls-tree", "-r", "HEAD", "--", "services/api"],
                )
                self.assertEqual(run_mock.call_args.kwargs.get("encoding"), "utf-8")
                self.assertEqual(run_mock.call_args.kwargs.get("errors"), "replace")

        # Unscoped equivalent inside services/api should produce the exact same fingerprint
        root_stdout = "\n".join(
            [
                "100644 blob 111aaa\tpackage.json",
                "100644 blob 222bbb\tsrc/routes/health.ts",
            ]
        )
        ok_root_res = types.SimpleNamespace(returncode=0, stdout=root_stdout)
        with mock.patch.object(central_memory_mcp.subprocess, "run", return_value=ok_root_res):
            fp_root = central_memory_mcp._blueprint_fingerprint("/repo/services/api", subdir=".")

        self.assertEqual(fp_scoped, fp_root)

    def test_memory_search_flags_stale_blueprints_by_default_and_discards_when_disabled(self) -> None:
        search_fn = _unwrap_tool(central_memory_mcp.memory_search)

        stale_blueprint = types.SimpleNamespace(
            id="bp-stale",
            score=0.95,
            payload={
                "document": "Old blueprint",
                "category": "blueprint",
                "git_tree_hash": "tree-old",
                "blueprint_fingerprint": "struct:old0000000000000",
            },
        )
        fresh_blueprint = types.SimpleNamespace(
            id="bp-fresh",
            score=0.91,
            payload={
                "document": "Fresh blueprint",
                "category": "blueprint",
                "git_tree_hash": "tree-old",
                "blueprint_fingerprint": "struct:curr000000000000",
            },
        )
        decision_hit = types.SimpleNamespace(
            id="dec-1",
            score=0.88,
            payload={
                "document": "Keep architectural decision",
                "category": "decision",
                "git_tree_hash": "tree-old",
            },
        )
        pattern_hit = types.SimpleNamespace(
            id="pat-1",
            score=0.85,
            payload={
                "document": "Global pattern",
                "category": "pattern",
                "git_tree_hash": None,
            },
        )

        mock_client = mock.MagicMock()
        mock_client.collection_exists.return_value = True
        mock_client.query_points.return_value = types.SimpleNamespace(
            points=[stale_blueprint, fresh_blueprint, decision_hit, pattern_hit]
        )

        with mock.patch.object(central_memory_mcp, "_qdrant", return_value=mock_client), mock.patch.object(
            central_memory_mcp, "_embed", return_value=[0.1] * 384
        ), mock.patch.object(
            central_memory_mcp, "_git_tree_hash", return_value="tree-current"
        ), mock.patch.object(
            central_memory_mcp, "_blueprint_fingerprint", return_value="struct:curr000000000000"
        ):
            # Default: include_stale_blueprints=True returns stale blueprint flagged
            res_default = search_fn(query="dropdown architecture", repo_path="/repo")
            # Opt-out: include_stale_blueprints=False discards stale blueprints
            res_filtered = search_fn(
                query="dropdown architecture",
                repo_path="/repo",
                include_stale_blueprints=False,
            )

        self.assertEqual(res_default["git_tree_hash"], "tree-current")
        self.assertEqual(res_default["blueprint_fingerprint"], "struct:curr000000000000")
        self.assertEqual(
            [hit["id"] for hit in res_default["hits"]],
            ["bp-stale", "bp-fresh", "dec-1", "pat-1"],
        )
        self.assertTrue(res_default["hits"][0]["stale"])
        self.assertEqual(res_default["hits"][0]["stale_reason"], "structural_change")
        self.assertFalse(res_default["hits"][1]["stale"])
        self.assertNotIn("stale_reason", res_default["hits"][1])
        self.assertFalse(res_default["hits"][2]["stale"])
        self.assertFalse(res_default["hits"][3]["stale"])

        self.assertEqual(
            [hit["id"] for hit in res_filtered["hits"]],
            ["bp-fresh", "dec-1", "pat-1"],
        )
        self.assertEqual(res_filtered["hits"][0]["document"], "Fresh blueprint")
        self.assertNotIn("document", res_filtered["hits"][0]["metadata"])

    def test_memory_search_legacy_blueprint_fallback_to_git_tree_hash(self) -> None:
        search_fn = _unwrap_tool(central_memory_mcp.memory_search)

        legacy_stale = types.SimpleNamespace(
            id="bp-legacy-stale",
            score=0.93,
            payload={
                "document": "Legacy blueprint",
                "category": "blueprint",
                "git_tree_hash": "tree-old",
            },
        )
        legacy_fresh = types.SimpleNamespace(
            id="bp-legacy-fresh",
            score=0.90,
            payload={
                "document": "Legacy fresh blueprint",
                "category": "blueprint",
                "git_tree_hash": "tree-current",
            },
        )

        mock_client = mock.MagicMock()
        mock_client.collection_exists.return_value = True
        mock_client.query_points.return_value = types.SimpleNamespace(
            points=[legacy_stale, legacy_fresh]
        )

        with mock.patch.object(central_memory_mcp, "_qdrant", return_value=mock_client), mock.patch.object(
            central_memory_mcp, "_embed", return_value=[0.1] * 384
        ), mock.patch.object(
            central_memory_mcp, "_git_tree_hash", return_value="tree-current"
        ), mock.patch.object(
            central_memory_mcp, "_blueprint_fingerprint", return_value="struct:curr000000000000"
        ):
            res_default = search_fn(query="legacy", repo_path="/repo")
            res_filtered = search_fn(
                query="legacy", repo_path="/repo", include_stale_blueprints=False
            )

        self.assertTrue(res_default["hits"][0]["stale"])
        self.assertEqual(res_default["hits"][0]["stale_reason"], "git_tree_mismatch")
        self.assertFalse(res_default["hits"][1]["stale"])
        self.assertEqual([hit["id"] for hit in res_filtered["hits"]], ["bp-legacy-fresh"])

    def test_ensure_collection_creates_category_and_repo_name_indexes(self) -> None:
        mock_client = mock.MagicMock()
        mock_client.collection_exists.return_value = False

        central_memory_mcp._ensure_collection(mock_client)

        mock_client.create_collection.assert_called_once()
        indexed_fields = [
            (call.kwargs["field_name"], call.kwargs["field_schema"])
            for call in mock_client.create_payload_index.call_args_list
        ]
        self.assertEqual(
            indexed_fields,
            [
                ("category", central_memory_mcp.PayloadSchemaType.KEYWORD),
                ("repo_name", central_memory_mcp.PayloadSchemaType.KEYWORD),
            ],
        )

    def test_memory_search_repo_name_filtering_variants(self) -> None:
        search_fn = _unwrap_tool(central_memory_mcp.memory_search)

        def _run_search(**kwargs):
            mock_client = mock.MagicMock()
            mock_client.collection_exists.return_value = True
            mock_client.query_points.return_value = types.SimpleNamespace(points=[])
            with mock.patch.object(
                central_memory_mcp, "_qdrant", return_value=mock_client
            ), mock.patch.object(
                central_memory_mcp, "_embed", return_value=[0.1] * 384
            ):
                search_fn(query="auth pattern", **kwargs)
            return mock_client.query_points.call_args.kwargs["query_filter"]

        # repo_name with default include_global=True -> MatchAny(["billing-api", "global"])
        flt_with_global = _run_search(repo_name="billing-api")
        self.assertIsNotNone(flt_with_global)
        self.assertEqual(len(flt_with_global.must), 1)
        cond_with_global = flt_with_global.must[0]
        self.assertEqual(cond_with_global.key, "repo_name")
        self.assertIsInstance(cond_with_global.match, central_memory_mcp.MatchAny)
        self.assertEqual(cond_with_global.match.any, ["billing-api", "global"])

        # repo_name with include_global=False -> MatchValue("billing-api")
        flt_repo_only = _run_search(repo_name="billing-api", include_global=False)
        self.assertIsNotNone(flt_repo_only)
        self.assertEqual(len(flt_repo_only.must), 1)
        cond_repo_only = flt_repo_only.must[0]
        self.assertEqual(cond_repo_only.key, "repo_name")
        self.assertIsInstance(cond_repo_only.match, central_memory_mcp.MatchValue)
        self.assertEqual(cond_repo_only.match.value, "billing-api")

        # repo_name="global" with include_global=True -> MatchValue("global")
        flt_global_only = _run_search(repo_name="global", include_global=True)
        self.assertIsNotNone(flt_global_only)
        self.assertEqual(flt_global_only.must[0].key, "repo_name")
        self.assertIsInstance(flt_global_only.must[0].match, central_memory_mcp.MatchValue)
        self.assertEqual(flt_global_only.must[0].match.value, "global")

        # Empty repo_name -> no repo_name filter (query_filter is None when category="any")
        flt_empty = _run_search(repo_name="")
        self.assertIsNone(flt_empty)

    def test_memory_search_overfetches_when_excluding_stale_blueprints(self) -> None:
        search_fn = _unwrap_tool(central_memory_mcp.memory_search)

        stale_points = [
            types.SimpleNamespace(
                id=f"bp-stale-{i}",
                score=0.99 - i * 0.01,
                payload={
                    "document": f"Stale blueprint {i}",
                    "category": "blueprint",
                    "blueprint_fingerprint": "struct:old0000000000000",
                    "git_tree_hash": "tree-old",
                },
            )
            for i in range(5)
        ]
        valid_points = [
            types.SimpleNamespace(
                id="dec-valid",
                score=0.85,
                payload={
                    "document": "Valid decision",
                    "category": "decision",
                    "git_tree_hash": "tree-old",
                },
            ),
            types.SimpleNamespace(
                id="pat-valid",
                score=0.82,
                payload={
                    "document": "Valid pattern",
                    "category": "pattern",
                    "git_tree_hash": None,
                },
            ),
            types.SimpleNamespace(
                id="pat-extra",
                score=0.80,
                payload={
                    "document": "Extra pattern beyond limit",
                    "category": "pattern",
                    "git_tree_hash": None,
                },
            ),
        ]

        mock_client = mock.MagicMock()
        mock_client.collection_exists.return_value = True
        mock_client.query_points.return_value = types.SimpleNamespace(
            points=stale_points + valid_points
        )

        with mock.patch.object(central_memory_mcp, "_qdrant", return_value=mock_client), mock.patch.object(
            central_memory_mcp, "_embed", return_value=[0.1] * 384
        ), mock.patch.object(
            central_memory_mcp, "_git_tree_hash", return_value="tree-current"
        ), mock.patch.object(
            central_memory_mcp, "_blueprint_fingerprint", return_value="struct:curr000000000000"
        ):
            result = search_fn(
                query="architecture",
                repo_path="/repo",
                limit=2,
                include_stale_blueprints=False,
            )

        self.assertEqual(mock_client.query_points.call_args.kwargs["limit"], 15)
        self.assertEqual([hit["id"] for hit in result["hits"]], ["dec-valid", "pat-valid"])

    def test_memory_store_deterministic_doc_ids_and_blueprint_fingerprint(self) -> None:
        store_fn = _unwrap_tool(central_memory_mcp.memory_store)

        mock_client = mock.MagicMock()
        mock_client.collection_exists.return_value = True

        with mock.patch.object(central_memory_mcp, "AGENT_ROLE", "antigravity"), mock.patch.object(
            central_memory_mcp, "_qdrant", return_value=mock_client
        ), mock.patch.object(
            central_memory_mcp, "_embed", return_value=[0.1] * 384
        ), mock.patch.object(
            central_memory_mcp, "_git_tree_hash", return_value="tree-abc"
        ), mock.patch.object(
            central_memory_mcp, "_blueprint_fingerprint", return_value="struct:1234567890abcdef"
        ):
            # 1. Blueprint without topic_key overwrites cleanly for same (repo_name, subdir)
            bp_v1 = store_fn(
                content="Blueprint v1",
                category="blueprint",
                repo_name="billing-api",
                repo_path="/repo",
                subdir="src",
            )
            bp_v2 = store_fn(
                content="Blueprint v2 with updated layout",
                category="blueprint",
                repo_name="billing-api",
                repo_path="/repo",
                subdir="src",
            )
            self.assertEqual(bp_v1["id"], bp_v2["id"])
            self.assertIsNone(bp_v1["metadata"]["topic_key"])
            self.assertEqual(bp_v1["metadata"]["blueprint_fingerprint"], "struct:1234567890abcdef")

            # 2. Decision WITH topic_key overwrites cleanly for same (repo_name, subdir, topic_key)
            dec_key_v1 = store_fn(
                content="Use JWT v1",
                category="decision",
                repo_name="billing-api",
                subdir=".",
                topic_key="auth-flow",
            )
            dec_key_v2 = store_fn(
                content="Use JWT v2 with refresh rotation",
                category="decision",
                repo_name="billing-api",
                subdir=".",
                topic_key=" auth-flow ",
            )
            self.assertEqual(dec_key_v1["id"], dec_key_v2["id"])
            self.assertEqual(dec_key_v2["metadata"]["topic_key"], "auth-flow")
            self.assertIsNone(dec_key_v1["metadata"]["blueprint_fingerprint"])

            # 3. Decision WITHOUT topic_key keeps distinct doc_ids for different content
            dec_a = store_fn(
                content="Decision alpha",
                category="decision",
                repo_name="billing-api",
                subdir=".",
            )
            dec_b = store_fn(
                content="Decision beta",
                category="decision",
                repo_name="billing-api",
                subdir=".",
            )
            self.assertNotEqual(dec_a["id"], dec_b["id"])
            self.assertIsNone(dec_a["metadata"]["topic_key"])


class RuleConsistencyTests(unittest.TestCase):
    def test_global_rules_and_engineering_rules_stay_in_sync(self) -> None:
        global_rules_path = REPO_ROOT / "memory" / "GLOBAL_RULES.md"
        eng_rules_path = REPO_ROOT / "plugins" / "antigravity-sdlc" / "rules" / "ENGINEERING_RULES.md"

        global_text = global_rules_path.read_text(encoding="utf-8")
        eng_text = eng_rules_path.read_text(encoding="utf-8")

        for label, text in (("GLOBAL_RULES.md", global_text), ("ENGINEERING_RULES.md", eng_text)):
            with self.subTest(file=label):
                lower = text.lower()
                self.assertIn("> 15", text)
                self.assertTrue("8–15" in text or "8-15" in text)
                self.assertIn("<= 7", text)
                self.assertIn("debounced", lower)
                self.assertIn("searchable", lower)
                self.assertIn("db-first", lower)
                self.assertIn("LINQ/EF", text)
                self.assertIn("git commit", lower)
                self.assertIn("git clean -fd", lower)

    def test_qa_code_reviewer_dropdown_thresholds(self) -> None:
        qa_path = REPO_ROOT / "agents" / "qa-code-reviewer.md"
        qa_text = qa_path.read_text(encoding="utf-8")
        self.assertIn("[CRITICAL]", qa_text)
        self.assertIn("> 15", qa_text)
        self.assertIn("[WARNING]", qa_text)
        self.assertTrue("8–15" in qa_text or "8-15" in qa_text)

    def test_readme_docs_and_plugin_version_in_sync(self) -> None:
        plugin_json = json.loads(
            (REPO_ROOT / "plugins" / "antigravity-sdlc" / "plugin.json").read_text(encoding="utf-8")
        )
        plugin_version = plugin_json["version"]
        self.assertEqual(plugin_version, "2.1.0")

        for name in ("README.md", "README.id.md"):
            with self.subTest(file=name):
                text = (REPO_ROOT / name).read_text(encoding="utf-8")
                self.assertNotIn("4-Lane", text)
                self.assertIn(f"v{plugin_version}", text)

    def test_gemini_template_relocated_from_repo_root(self) -> None:
        self.assertFalse(
            (REPO_ROOT / "GEMINI.md").exists(),
            "Root GEMINI.md must be removed so Antigravity does not auto-load it as a workspace rule.",
        )
        self.assertTrue(
            (REPO_ROOT / "templates" / "GEMINI.md").is_file(),
            "templates/GEMINI.md must exist as the installer template source.",
        )

    def test_subagent_rule_deduplication_and_output_format_gate(self) -> None:
        for name in ("dotnet-cqrs-dev.md", "db-data-engineer.md", "devops-git-ops.md"):
            with self.subTest(agent=name):
                text = (REPO_ROOT / "agents" / name).read_text(encoding="utf-8")
                self.assertIn("ENGINEERING_RULES.md", text)
                self.assertNotIn("dropdown", text.lower())

        pr_fixer_text = (REPO_ROOT / "agents" / "pr-review-fixer.md").read_text(encoding="utf-8")
        self.assertIn("ENGINEERING_RULES.md", pr_fixer_text)
        self.assertNotIn("> 15", pr_fixer_text)
        self.assertNotIn("8–15", pr_fixer_text)
        self.assertNotIn("<= 7", pr_fixer_text)

        ui_proto_text = (REPO_ROOT / "agents" / "ui-prototyper.md").read_text(encoding="utf-8")
        self.assertIn("ENGINEERING_RULES.md", ui_proto_text)
        self.assertNotIn("> 15", ui_proto_text)

        team_lead_text = (REPO_ROOT / "agents" / "sdlc-team-lead.md").read_text(encoding="utf-8")
        output_section = team_lead_text.split("# Mandatory Final Output Format", 1)[1]
        self.assertIn("Lane 0 (`docs`) & Lane 1A (`micro`)", output_section)
        self.assertIn("**skip** the 3 handover tables", output_section)
        self.assertIn("Lane 1B (`small`) & Lane 2/3 (`standard`/`complex`)", output_section)


if __name__ == "__main__":
    unittest.main()
