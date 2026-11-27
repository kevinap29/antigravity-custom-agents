#!/usr/bin/env python3
"""
Centralized memory MCP server for Antigravity (qdrant-client 1.20+ & fastembed).
Runs local CPU embeddings (BAAI/bge-small-en-v1.5) locally and syncs vectors
to embedded local Qdrant (QDRANT_LOCAL_PATH), localhost Qdrant server, or
remote Qdrant VPS over HTTPS REST / SSH tunnel.
Validates AGENT_ROLE for write permissions and structural blueprint_fingerprint
(with git_tree_hash fallback) for staleness checks.
"""

import fnmatch
import hashlib
import os
import subprocess
import time
import uuid
from pathlib import Path, PurePosixPath
from typing import Literal

from fastembed import TextEmbedding
from fastmcp import FastMCP
from qdrant_client import QdrantClient
from qdrant_client.models import (
    Distance,
    FieldCondition,
    Filter,
    MatchAny,
    MatchValue,
    PayloadSchemaType,
    PointStruct,
    VectorParams,
)

mcp = FastMCP("central-memory-hub")

HUB_DIR = Path(os.environ.get("AGENT_HUB_DIR", "~/.gemini")).expanduser().resolve()
MEMORY_DIR = HUB_DIR / "memory"
QDRANT_LOCAL_PATH = os.environ.get("QDRANT_LOCAL_PATH", "").strip()
QDRANT_URL = os.environ.get("QDRANT_URL", "http://127.0.0.1:6333").rstrip("/")
QDRANT_API_KEY = os.environ.get("QDRANT_API_KEY") or None
AGENT_ROLE = os.environ.get("AGENT_ROLE", "antigravity").lower()
COLLECTION_NAME = "agent_hub_memory"
EMBED_MODEL = "BAAI/bge-small-en-v1.5"
EMBED_DIM = 384
ALLOWED_WRITERS = {"hermes", "antigravity"}
_STRUCTURAL_MANIFEST_NAMES = frozenset(
    {
        "package.json",
        "tsconfig.json",
        "pyproject.toml",
        "requirements.txt",
        "Dockerfile",
        "Web.config",
        "appsettings.json",
        "plugin.json",
        "hooks.json",
        "go.mod",
        "Cargo.toml",
    }
)
_STRUCTURAL_MANIFEST_PATTERNS = (
    "*.sln",
    "*.csproj",
    "svelte.config.*",
    "docker-compose*.yml",
    "docker-compose*.yaml",
)

_client: QdrantClient | None = None
_embedder: TextEmbedding | None = None


def _qdrant() -> QdrantClient:
    global _client
    if _client is None:
        if QDRANT_LOCAL_PATH:
            local_path = Path(QDRANT_LOCAL_PATH).expanduser().resolve()
            local_path.mkdir(parents=True, exist_ok=True)
            _client = QdrantClient(path=str(local_path))
        else:
            _client = QdrantClient(
                url=QDRANT_URL,
                port=443 if QDRANT_URL.startswith("https://") else 6333,
                api_key=QDRANT_API_KEY,
                prefer_grpc=False,
                timeout=30,
            )
    return _client


def _get_embedder() -> TextEmbedding:
    global _embedder
    if _embedder is None:
        _embedder = TextEmbedding(model_name=EMBED_MODEL)
    return _embedder


def _embed(text: str) -> list[float]:
    return next(_get_embedder().embed([text])).tolist()


def _ensure_collection(client: QdrantClient) -> None:
    if not client.collection_exists(COLLECTION_NAME):
        client.create_collection(
            collection_name=COLLECTION_NAME,
            vectors_config=VectorParams(size=EMBED_DIM, distance=Distance.COSINE),
        )
        client.create_payload_index(
            collection_name=COLLECTION_NAME,
            field_name="category",
            field_schema=PayloadSchemaType.KEYWORD,
        )
        client.create_payload_index(
            collection_name=COLLECTION_NAME,
            field_name="repo_name",
            field_schema=PayloadSchemaType.KEYWORD,
        )


def _require_writer() -> None:
    if AGENT_ROLE not in ALLOWED_WRITERS:
        raise PermissionError(
            f"Write denied for AGENT_ROLE='{AGENT_ROLE}'. Allowed writers: {sorted(ALLOWED_WRITERS)}."
        )


def _normalize_subdir(subdir: str) -> str:
    clean = subdir.strip().replace("\\", "/")
    while clean.startswith("./"):
        clean = clean[2:]
    clean = clean.strip("/")
    return "" if clean in ("", ".") else clean


def _git_tree_hash(repo_path: str, subdir: str = ".") -> str | None:
    if not repo_path:
        return None
    clean_subdir = _normalize_subdir(subdir)
    target = "HEAD^{tree}" if not clean_subdir else f"HEAD:{clean_subdir}"
    res = subprocess.run(
        ["git", "-C", repo_path, "rev-parse", target],
        capture_output=True,
        text=True,
        encoding="utf-8",
        errors="replace",
    )
    return res.stdout.strip() if res.returncode == 0 else None


def _is_structural_manifest(filename: str) -> bool:
    if filename in _STRUCTURAL_MANIFEST_NAMES:
        return True
    return any(fnmatch.fnmatchcase(filename, pat) for pat in _STRUCTURAL_MANIFEST_PATTERNS)


def _blueprint_fingerprint(repo_path: str, subdir: str = ".") -> str | None:
    if not repo_path:
        return None
    clean_subdir = _normalize_subdir(subdir)
    cmd = ["git", "-C", repo_path, "ls-tree", "-r", "HEAD"]
    if clean_subdir:
        cmd.extend(["--", clean_subdir])
    res = subprocess.run(
        cmd,
        capture_output=True,
        text=True,
        encoding="utf-8",
        errors="replace",
    )
    if res.returncode != 0 or not res.stdout.strip():
        return None

    manifest_entries: list[str] = []
    dir_entries: set[str] = set()
    subdir_prefix = f"{clean_subdir}/" if clean_subdir else ""

    for line in res.stdout.splitlines():
        if not line.strip():
            continue
        meta, sep, raw_path = line.partition("\t")
        if not sep:
            continue
        meta_parts = meta.split()
        if len(meta_parts) < 3:
            continue
        blob_hash = meta_parts[2]
        rel_path = raw_path.strip().lstrip("/")
        if subdir_prefix:
            if rel_path.startswith(subdir_prefix):
                rel_path = rel_path[len(subdir_prefix) :]
            elif rel_path == clean_subdir:
                rel_path = PurePosixPath(rel_path).name

        posix_path = PurePosixPath(rel_path)
        if _is_structural_manifest(posix_path.name):
            manifest_entries.append(f"manifest:{rel_path}:{blob_hash}")

        parent_parts = posix_path.parts[:-1]
        for depth in range(1, min(len(parent_parts), 2) + 1):
            dir_path = "/".join(parent_parts[:depth])
            if dir_path and dir_path != ".":
                dir_entries.add(f"dir:{dir_path}")

    signals = sorted(set(manifest_entries) | dir_entries)
    digest = hashlib.sha256("\n".join(signals).encode("utf-8")).hexdigest()
    return f"struct:{digest[:16]}"


@mcp.tool
def memory_get_rules(
    scope: Literal["global", "architecture", "all"] = "global",
) -> dict:
    """Read global markdown rule files from AGENT_HUB_DIR/memory/."""
    files = {
        "global": MEMORY_DIR / "GLOBAL_RULES.md",
        "architecture": MEMORY_DIR / "ARCHITECTURE_NOTES.md",
    }
    selected = files.keys() if scope == "all" else [scope]
    output: dict[str, str] = {}
    for key in selected:
        path = files[key]
        output[key] = path.read_text(encoding="utf-8") if path.exists() else ""
    return {"role": AGENT_ROLE, "rules": output}


@mcp.tool
def memory_search(
    query: str,
    category: Literal["blueprint", "decision", "pattern", "any"] = "any",
    repo_path: str = "",
    subdir: str = ".",
    limit: int = 5,
    min_score: float = 0.72,
    repo_name: str = "",
    include_global: bool = True,
    include_stale_blueprints: bool = True,
) -> dict:
    """Search vector memory; flags or discards stale blueprints via structural fingerprint."""
    client = _qdrant()
    if not client.collection_exists(COLLECTION_NAME):
        return {"role": AGENT_ROLE, "hits": [], "note": "Collection uninitialized."}

    conditions = []
    if category != "any":
        conditions.append(FieldCondition(key="category", match=MatchValue(value=category)))

    normalized_repo = repo_name.strip()
    if normalized_repo:
        if include_global and normalized_repo != "global":
            conditions.append(
                FieldCondition(key="repo_name", match=MatchAny(any=[normalized_repo, "global"]))
            )
        else:
            conditions.append(
                FieldCondition(key="repo_name", match=MatchValue(value=normalized_repo))
            )

    current_fp = _blueprint_fingerprint(repo_path, subdir) if repo_path else None
    current_tree = _git_tree_hash(repo_path, subdir) if repo_path else None
    query_filter = Filter(must=conditions) if conditions else None
    should_overfetch = not include_stale_blueprints and (
        current_fp is not None or current_tree is not None
    )
    fetch_limit = min(max(limit * 3, 15), 50) if should_overfetch else limit

    response = client.query_points(
        collection_name=COLLECTION_NAME,
        query=_embed(query),
        query_filter=query_filter,
        limit=fetch_limit,
        score_threshold=min_score,
        with_payload=True,
    )

    hits = []
    for item in response.points:
        payload = dict(item.payload or {})
        document = payload.pop("document", "")
        is_stale = False
        stale_reason: str | None = None
        if payload.get("category") == "blueprint":
            stored_fp = payload.get("blueprint_fingerprint")
            if stored_fp and current_fp:
                if stored_fp != current_fp:
                    is_stale = True
                    stale_reason = "structural_change"
            elif current_tree:
                if payload.get("git_tree_hash") != current_tree:
                    is_stale = True
                    stale_reason = "git_tree_mismatch"
            if is_stale and not include_stale_blueprints:
                continue

        hit = {
            "id": str(item.id),
            "score": round(float(item.score), 4),
            "document": document,
            "metadata": payload,
            "stale": is_stale,
        }
        if is_stale and stale_reason is not None:
            hit["stale_reason"] = stale_reason
        hits.append(hit)
        if len(hits) >= limit:
            break

    return {
        "role": AGENT_ROLE,
        "git_tree_hash": current_tree,
        "blueprint_fingerprint": current_fp,
        "hits": hits[:limit],
    }


@mcp.tool
def memory_store(
    content: str,
    category: Literal["blueprint", "decision", "pattern"],
    repo_name: str = "global",
    repo_path: str = "",
    subdir: str = ".",
    tags: list[str] | None = None,
    topic_key: str = "",
) -> dict:
    """Store a memory vector record in Qdrant (collection: agent_hub_memory)."""
    _require_writer()
    client = _qdrant()
    _ensure_collection(client)

    tree_hash = _git_tree_hash(repo_path, subdir) if repo_path else None
    bp_fingerprint = _blueprint_fingerprint(repo_path, subdir) if repo_path else None
    normalized_key = topic_key.strip()
    if normalized_key:
        id_seed = f"{category}:{repo_name}:{subdir}:{normalized_key}"
    elif category == "blueprint":
        id_seed = f"blueprint:{repo_name}:{subdir}"
    else:
        id_seed = f"{category}:{repo_name}:{subdir}:{content}"
    doc_id = str(uuid.uuid5(uuid.NAMESPACE_URL, id_seed))

    metadata = {
        "category": category,
        "repo_name": repo_name,
        "subdir": subdir,
        "git_tree_hash": tree_hash,
        "blueprint_fingerprint": bp_fingerprint,
        "tags": tags or [],
        "topic_key": normalized_key or None,
        "stored_at": int(time.time()),
        "stored_by": AGENT_ROLE,
    }

    client.upsert(
        collection_name=COLLECTION_NAME,
        points=[
            PointStruct(
                id=doc_id,
                vector=_embed(content),
                payload={"document": content, **metadata},
            )
        ],
    )
    return {"status": "stored", "id": doc_id, "metadata": metadata}


@mcp.tool
def memory_forget(point_id: str) -> dict:
    """Delete a memory record by ID from Qdrant."""
    _require_writer()
    client = _qdrant()
    if not client.collection_exists(COLLECTION_NAME):
        return {"status": "noop"}
    client.delete(collection_name=COLLECTION_NAME, points_selector=[point_id])
    return {"status": "deleted", "id": point_id}


if __name__ == "__main__":
    mcp.run()
