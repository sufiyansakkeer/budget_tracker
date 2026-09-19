# LEARNING.md

Progress tracker for the React Native + TypeScript rebuild of Budget Tracker.

**Rule:** a concept moves to *Learned* only after I demonstrate it by explaining,
debugging, implementing, or solving a related problem — not because it was explained to me.

## Status legend
- `[ ]` Not started
- `[~]` In progress / explained but not demonstrated
- `[x]` Learned (demonstrated)

## TypeScript
- [ ] `typeof` on a value vs. a type position (used in `store.ts`)
- [ ] `ReturnType<T>` and other built-in utility types
- [ ] Generic *instantiation expressions* (`f<T>`) vs. *calling* a generic (`f<T>()`)
- [ ] `as const` and literal types (used in `storageKeys.ts`)
- [ ] Discriminated unions for domain modelling (transactions, categories)
- [ ] `PayloadAction<T>` and how RTK infers action types
- [ ] Avoiding `any`: `unknown`, narrowing, type guards

## React fundamentals
- [ ] Component vs. element vs. render
- [ ] Props typing with `PropsWithChildren`
- [ ] State colocation vs. lifting state
- [ ] Rules of Hooks (why a hook can't be called conditionally or returned/stored)
- [ ] `useMemo` / `useCallback` — when they actually matter
- [ ] Context: what it solves and what it costs

## React Native fundamentals
- [ ] Flexbox layout differences from web/Flutter
- [ ] `StyleSheet.create` vs. inline styles
- [ ] Safe area handling (`react-native-safe-area-context`)
- [ ] `FlatList` virtualization and list performance
- [ ] Platform differences and `Platform.select`
- [ ] New Architecture (Fabric/TurboModules/Nitro) — what it changes

## Architecture
- [ ] Feature-first folder structure (`src/features/*`)
- [ ] Provider composition (`AppProviders`)
- [ ] Redux Toolkit: slices, reducers, typed hooks
- [ ] Server state (TanStack Query) vs. client state (Redux) — which goes where
- [ ] Local persistence: MMKV (key/value) vs. WatermelonDB (relational)
- [ ] Navigation structure: stacks vs. tabs, typed route params
- [ ] Theming and design tokens

## Production practices
- [ ] Form validation with react-hook-form + zod
- [ ] Error boundaries and crash handling
- [ ] i18n setup and key organisation
- [ ] Testing: unit, component, and what is worth testing
- [ ] Lint/format/type-check as a gate

## Open questions / current findings

All four findings from the 2026-09-15 review are now resolved in the code:

1. ~~`src/store/hooks.ts` — `withTypes` written without `()`.~~ Fixed. `withTypes<T>` on its
   own is a *generic instantiation expression*: it evaluates to the uncalled function, so
   `useAppSelector` was the `useSelector` factory rather than a selector hook. TypeScript
   accepted it because an instantiation expression is valid syntax with a valid type — the
   type was just not the one the name promised. Now `withTypes<RootState>()`.
2. ~~`__tests__/App.test.tsx` imports `../App`.~~ The template smoke test was removed. Rendering
   `App` in Jest would need mocks for MMKV (Nitro) and WatermelonDB (JSI); the pure domain
   modules are tested directly instead (45 tests across budget maths, currency, grouping).
3. ~~Placeholder files are empty.~~ `src/theme/*`, `src/localization/i18n.ts` and the feature
   barrels are implemented. `src/features/auth` and `src/features/chat` are still empty — they
   have no counterpart in the Flutter app and are outside the MVP scope.
4. ~~`storageService.getBolean` typo.~~ Renamed to `getBoolean`.

### Worth reading, in this order

The MVP was implemented in full on 2026-09-17. To use it as study material rather than a
black box, read it in dependency order — each layer only depends on the ones above it:

1. `src/domain/` — pure TypeScript, no React, no database. Start with
   `budget/calculations.ts` and its test; it is the whole business model.
2. `src/database/` — WatermelonDB schema, models and seeding.
3. `src/features/*/api/` — repositories that map live DB models to plain objects.
4. `src/features/*/hooks/` — React Query wrappers and cache invalidation.
5. `src/theme/` + `src/components/` — the design tokens and the shared UI kit.
6. `src/features/*/screens/` — the screens themselves.

## Session log
- 2026-09-15 — Baseline review of the scaffolded `src/` tree. Nothing demonstrated yet.
- 2026-09-17 — Mode switched: the user asked me to finish the project, so I implemented the
  core MVP (onboarding, dashboard, expenses, budgets, settings) end to end. The checkboxes
  above are deliberately left unticked — the rule still stands that a concept counts as
  learned only once the user demonstrates it, and reading my code is not demonstrating.
  Good candidates for demonstrating: add the reports feature, or port `bills` from Flutter.
