# Global Engineering Rules
- Never push directly to `main`, `master`, or `develop`; always work on feature branches and open a PR.
- DB-First mandatory: never use EF Core Code-First migrations; use LINQ/EF if already present in the project (no raw SQL template strings).
- Write targeted unit tests for every behavioral change; never weaken assertions to pass tests.
- Prefer explicit typing, structured logging, parameterized queries, and atomic DB mutations; zero hardcoded secrets.
- Check existing helpers/validators (DRY) and keep changes strictly scoped (KISS & Zero Regression).
