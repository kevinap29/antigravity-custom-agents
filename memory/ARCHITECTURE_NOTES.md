# Architecture Notes
- **Primary Backend Stack:** C# / .NET 6–11 (CQRS, Vertical Slice, DDD, EF Core/LINQ, SQLite WAL / SQL Server) & legacy .NET Framework / ASP.NET WebForms.
- **Primary Frontend & Mobile Stack:** TypeScript, SvelteKit, Tailwind CSS, .NET MAUI Hybrid Blazor.
- **Central Memory:** Hosted on Ubuntu VPS (`<VPS_IP>`) Qdrant native binary (`<QDRANT_URL>`, e.g., `http://127.0.0.1:6333` via SSH tunnel or HTTPS port 443, collection `agent_hub_memory`). Embeddings run locally via `fastembed` (`BAAI/bge-small-en-v1.5`).
- **Staleness Policy:** Blueprint vectors carry `git_tree_hash` metadata and are auto-discarded on search if Git HEAD tree hash has changed.
