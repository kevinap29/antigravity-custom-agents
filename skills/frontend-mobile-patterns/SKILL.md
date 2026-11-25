---
name: frontend-mobile-patterns
description: Implementation patterns for SvelteKit (Svelte 4 vs 5, routing, SSR/API routes) and .NET MAUI Hybrid Blazor (lifecycle, BlazorWebView, JS Interop, Windows target builds). Use when building or modifying UI in SvelteKit or .NET MAUI Hybrid Blazor.
---

# Frontend & Cross-Platform Mobile Patterns

## 1. SvelteKit (TypeScript + Tailwind CSS)
- **Detect Svelte Version:** Check `package.json` before writing components:
  - **Svelte 5:** Use runes (`$state`, `$derived`, `$effect`, `$props`).
  - **Svelte 4:** Use `export let`, `$:`, `onMount`/`onDestroy`.
  - **FORBIDDEN:** Mixing Svelte 4 and Svelte 5 syntax within a single component.
- **Routing & Server Scope:** Handle `.svelte`, `+layout.svelte`, `+page.ts`, `+page.server.ts`, `+server.ts`, matching the adapter in `svelte.config.*`.
- **Docs & Autofixer:** Use `svelte` MCP (`get-documentation`, `svelte-autofixer`) and `modern-web-guidance` skill for modern HTML/CSS/DOM APIs.

## 2. .NET MAUI Hybrid Blazor (Android / Desktop)
- **Components & Host Scope:** Handle `.razor`, `@code`/code-behind, `EditForm` validation, `MauiProgram.cs`, `BlazorWebView`, local DI services, JS Interop, and Android/Desktop safe areas.
- **Lifecycle & Cleanup:** Use `OnInitializedAsync`, `OnParametersSetAsync`, `StateHasChanged`, and implement `IDisposable`/`IAsyncDisposable` to clean up timers, event listeners, and subscriptions.
- **Windows Sandbox Build Verification:** If Android SDK workloads are missing in sandbox, build against the Windows target framework in `.csproj` (e.g., `dotnet build -f net8.0-windows10...` or `-f net10.0-windows10...`) and report the exact built target framework.
- **Docs:** Use `context7` MCP (`resolve-library-id` & `query-docs`) for official `.NET MAUI` / `Blazor` references when available.

## 3. UI Standards, Contracts & Cleanliness
- **Custom Searchable Dropdown (Mandatory):** Never use a plain native `<select>` for HTML dropdowns. Always build/reuse a custom dropdown component with a built-in search `<input>` inside the dropdown panel, **debounced** filtering/querying (250–300ms, properly disposed on unmount/`IDisposable`), click-outside close, Escape/keyboard navigation, empty state, and ARIA attributes.
- **UX States & Accessibility:** Handle **loading**, **empty**, and **error** states, prevent double-submit during async actions, add `aria-label` on icon buttons, label forms, and maintain Light/Dark Mode contrast.
- **DTO Contract Sync:** Match property names, JSON casing, data types, and nullability 100% with the backend.
- **No Hardcoding:** Centralize constants per project convention (`constants.ts` in SvelteKit or existing constant class/`[Name]Constant.cs` in Blazor).
- **Composition, ISP & SRP:** Decompose via **Composition over Inheritance** (avoid god-props or cross-domain boolean flags; use **Inline & Split** when needed). Keep pure formatting/state logic separate from DOM/API calls.
