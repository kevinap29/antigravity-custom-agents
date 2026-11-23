---
name: frontend-mobile-patterns
description: Referensi pola implementasi SvelteKit (Svelte 4 vs 5, routing, SSR/API routes) dan .NET MAUI Hybrid Blazor (lifecycle, BlazorWebView, JS Interop, target build Windows). Gunakan saat membangun atau memodifikasi UI di SvelteKit atau .NET MAUI Hybrid Blazor.
---

# Frontend & Cross-Platform Mobile Patterns

## 1. SvelteKit (TypeScript + Tailwind CSS)

- **Deteksi Versi Svelte:** Cek `package.json` sebelum menulis komponen:
  - **Svelte 5:** Gunakan runes (`$state`, `$derived`, `$effect`, `$props`).
  - **Svelte 4:** Gunakan `export let`, `$:`, `onMount`/`onDestroy`.
  - **DILARANG** mencampur sintaks Svelte 4 dan Svelte 5 dalam satu komponen.
- **Cakupan Routing & Server:** Tangani `.svelte`, `+layout.svelte`, `+page.ts`, `+page.server.ts`, `+server.ts`, dan sesuaikan dengan adapter di `svelte.config.*`.
- **Dokumentasi & Autofixer:** Manfaatkan MCP `svelte` (`get-documentation`, `svelte-autofixer`) serta skill `modern-web-guidance` untuk HTML/CSS/DOM modern.

## 2. .NET MAUI Hybrid Blazor (Android / Desktop)

- **Cakupan Komponen & Host:** Tangani `.razor`, `@code`/code-behind, `EditForm` validation, `MauiProgram.cs`, `BlazorWebView`, DI service lokal, JS Interop, dan safe-area Android/Desktop.
- **Lifecycle & Cleanup:** Gunakan `OnInitializedAsync`, `OnParametersSetAsync`, `StateHasChanged`, serta wajib implementasikan `IDisposable`/`IAsyncDisposable` untuk membersihkan timer, event listener, atau subscription.
- **Verifikasi Build di Sandbox Windows:** Jika workload Android SDK tidak tersedia di environment sandbox, jalankan build dengan filter target framework Windows yang ada di `.csproj` (misal `dotnet build -f net8.0-windows10...` atau `-f net10.0-windows10...`) dan laporkan target framework yang berhasil di-build.
- **Dokumentasi:** Gunakan MCP `context7` (`context7_context7`: `resolve-library-id` & `query-docs`) untuk referensi resmi `.NET MAUI` / `Blazor` bila tersedia.

## 3. Standar UI, Kontrak & Kebersihan

- **UX States & Aksesibilitas:** Tangani **loading state**, **empty state**, **error state**, cegah double-submit saat async action berjalan, sediakan `aria-label` pada tombol ikon, label form, dan jaga kontras Light/Dark Mode.
- **Sinkronisasi Kontrak DTO:** Properti, casing JSON, tipe data, dan nullability harus cocok 100% dengan backend.
- **No Hardcoding:** Pusatkan konstanta sesuai konvensi proyek (`constants.ts` di SvelteKit atau class konstanta eksisting/`[Nama]Constant.cs` di Blazor).
- **Komposisi, ISP & SRP:** Pecah komponen dengan **Composition over Inheritance** (hindari god-props atau boolean flag lintas domain; gunakan **Inline & Split** bila perlu). Pisahkan pure formatting/state logic dari DOM/API call.
