#!/usr/bin/env python3
"""
Centralized memory MCP server for Antigravity (qdrant-client 1.20+ & fastembed).
Runs local CPU embeddings (BAAI/bge-small-en-v1.5) locally and syncs vectors
to embedded local Qdrant (QDRANT_LOCAL_PATH), localhost Qdrant server, or
remote Qdrant VPS over HTTPS REST / SSH tunnel.
Validates AGENT_ROLE for write permissions and git_tree_hash for staleness checks.
"""

import os
import subprocess
import time
import uuid
from pathlib import Path
from typing import Literal

from fastembed import TextEmbedding
from fastmcp import FastMCP
from qdrant_client import QdrantClient
from qdrant_client.models import (
    Distance,
    FieldCondition,
    Filter,
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


def _require_writer() -> None:
    if AGENT_ROLE not in ALLOWED_WRITERS:
        raise PermissionError(
            f"Write denied for AGENT_ROLE='{AGENT_ROLE}'. Allowed writers: {sorted(ALLOWED_WRITERS)}."
        )


def _git_tree_hash(repo_path: str, subdir: str = ".") -> str | None:
    if not repo_path:
        return None
    target = "HEAD^{tree}" if subdir in ("", ".") else f"HEAD:{subdir.strip('/')}"
    res = subprocess.run(
        ["git", "-C", repo_path, "rev-parse", target],
        capture_output=True,
        text=True,
    )
    return res.stdout.strip() if res.returncode == 0 else None


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
) -> dict:
    """Search vector memory; auto-discards stale blueprint results using git_tree_hash."""
    client = _qdrant()
    if not client.collection_exists(COLLECTION_NAME):
        return {"role": AGENT_ROLE, "hits": [], "note": "Collection uninitialized."}

    conditions = []
    if category != "any":
        conditions.append(FieldCondition(key="category", match=MatchValue(value=category)))

    current_tree = _git_tree_hash(repo_path, subdir) if repo_path else None
    query_filter = Filter(must=conditions) if conditions else None

    response = client.query_points(
        collection_name=COLLECTION_NAME,
        query=_embed(query),
        query_filter=query_filter,
        limit=limit,
        score_threshold=min_score,
        with_payload=True,
    )

    hits = []
    for item in response.points:
        payload = dict(item.payload or {})
        document = payload.pop("document", "")
        if payload.get("category") == "blueprint" and current_tree:
            if payload.get("git_tree_hash") != current_tree:
                continue
        hits.append(
            {
                "id": str(item.id),
                "score": round(float(item.score), 4),
                "document": document,
                "metadata": payload,
            }
        )

    return {"role": AGENT_ROLE, "git_tree_hash": current_tree, "hits": hits}


@mcp.tool
def memory_store(
    content: str,
    category: Literal["blueprint", "decision", "pattern"],
    repo_name: str = "global",
    repo_path: str = "",
    subdir: str = ".",
    tags: list[str] | None = None,
) -> dict:
    """Store a memory vector record in Qdrant (collection: agent_hub_memory)."""
    _require_writer()
    client = _qdrant()
    _ensure_collection(client)

    tree_hash = _git_tree_hash(repo_path, subdir) if repo_path else None
    doc_id = str(uuid.uuid5(uuid.NAMESPACE_URL, f"{category}:{repo_name}:{subdir}:{content}"))

    metadata = {
        "category": category,
        "repo_name": repo_name,
        "subdir": subdir,
        "git_tree_hash": tree_hash,
        "tags": tags or [],
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
