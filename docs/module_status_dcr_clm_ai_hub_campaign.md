# Module Status Review

Review date: 2026-06-08

This document summarizes what is currently included in the `DCR`, `CLM`, `ai_hub`, and `campaign` modules based on code inspection.

## Overall Summary

| Module | Included in codebase | Completion status | Notes |
| --- | --- | --- | --- |
| `CLM` | Yes | Mostly completed | Strongest module in this set. Has screens, provider, local database, sync, analytics, and flow into DCR. |
| `DCR` | Yes | Mostly completed | Has dashboard, doctor visit, chemist visit, sample sheet, signature, and RCPA flows backed by local DB/provider. |
| `ai_hub` | Yes | UI completed, data integration pending | Screens exist and are visually complete, but they use static datasets and are not connected from the dashboard. |
| `campaign` | Yes | Partially completed | Basic campaign list and planning UI exist, but they are mock-data driven and not integrated with real APIs/workflows. |

## 1. CLM Module

### Included

- Home dashboard for CLM with stats, sync banner, quick actions, and recent presentations.
- Doctor list flow.
- Doctor profile flow.
- Doctor check-in screen.
- Doctor location management.
- CLM cart and AI cart flows.
- CLM player/presentation flow.
- Call report screen.
- Sync/download screen.
- Provider-based state management in `ClmProvider`.
- Local SQLite storage in `ClmDatabaseService`.
- Sync/download/upload logic in `ClmSyncService`.
- Analytics and AI helper services (`clm_analytics_service.dart`, `clm_ai_service.dart`, `clm_geo_service.dart`).
- Handoff from CLM call report into DCR flow.

### What Looks Completed

- Provider and local persistence are implemented.
- Doctors, brands, slides, sessions, analytics, call reports, and doctor locations are persisted locally.
- Master sync exists for doctors, brands, and slide metadata.
- Media download exists for brand slides.
- Pending session and analytics upload exists.
- CLM to DCR handoff is implemented through `Submit & Fill DCR`.
- The module appears functionally deeper than a prototype.

### Gaps / Incomplete Areas

- The CLM entry from the main dashboard is currently commented out, so the module is not exposed from the main home menu.
- The database includes demo seeding, which suggests part of the experience still depends on seeded sample data for testing/demo.
- I did not verify end-to-end server behavior, so sync/API readiness is based on code presence, not runtime confirmation.

### Status

`CLM` is included and mostly completed, with the main remaining concern being app-level exposure and final runtime validation.

## 2. DCR Module

### Included

- DCR dashboard.
- Doctor visit screen.
- Chemist visit screen.
- Sample sheet screen.
- Signature capture screen.
- RCPA matrix screen.
- Provider-based state management in `DcrProvider`.
- Local SQLite tables and CRUD support through `ClmDatabaseService`.
- Summary counts for doctor visits, chemist visits, and total samples.
- Draft/submission style workflow.
- Support for joint working employees.

### What Looks Completed

- DCR has a structured provider and storage layer.
- Doctor visit create/edit/delete is implemented.
- Chemist visit create/edit/delete is implemented.
- Sample allocation flow is implemented with stock deduction.
- Signature save/load/delete flow is implemented.
- RCPA save flow is implemented.
- CLM flow can open DCR directly after call reporting.

### Gaps / Incomplete Areas

- The new DCR module is not directly exposed from the main dashboard menu; it is mainly reachable from CLM.
- I did not validate whether final DCR submission posts to a backend or remains local/offline-first.
- Runtime/API verification was not performed.

### Status

`DCR` is included and mostly completed as a module, especially for local workflow and data capture.

## 3. AI Hub Module

### Included

- AI Hub landing screen.
- Sales Assistant screen.
- Product Performance screen.
- Doctor Review screen.
- Employee Reports screen.

### What Looks Completed

- UI structure is present for all four AI submodules.
- Navigation between AI Hub and the individual AI screens exists inside the module.
- Visual presentation is polished enough for demo/showcase use.

### Gaps / Incomplete Areas

- The screens rely on static values and hardcoded insight content rather than provider/API-backed data.
- There is no dedicated provider/service layer for the AI Hub module.
- The AI section in the main dashboard is commented out, so the module is not currently enabled from the app home.
- This module looks like a demo/prototype UI rather than a completed production workflow.

### Status

`ai_hub` is included, but only the UI layer looks complete. Real data integration and dashboard enablement are still pending.

## 4. Campaign Module

### Included

- Campaign list screen with tabs for `Action Required`, `Active`, and `Completed`.
- Campaign planning screen for selecting doctors.

### What Looks Completed

- Basic campaign browsing UI is implemented.
- Planning UI with doctor selection rules is implemented.
- The screens are usable as a prototype/demo flow.

### Gaps / Incomplete Areas

- Campaign list uses mock campaign data.
- Campaign planning uses mock doctor data.
- API integration is marked as TODO.
- Refresh after planning is marked as TODO.
- Active/completed campaign detail flow is marked as TODO.
- I did not find active dashboard wiring to `CampaignListScreen`.
- The current dashboard action labeled `Daily POBS campaign` routes to `ChemistListScreen`, not the campaign module.

### Status

`campaign` is included but only partially completed. It is currently a prototype UI, not a fully integrated module.

## Final Assessment

### Modules that are largely complete

- `CLM`
- `DCR`

### Modules that are present but not fully completed

- `ai_hub`
- `campaign`

### Main actions recommended

- Re-enable and test dashboard access for `CLM` and `ai_hub`.
- Decide whether `DCR` should also be directly accessible from the dashboard.
- Replace mock data in `campaign` with API/service integration.
- Add real provider/service-backed data pipelines for `ai_hub`.
