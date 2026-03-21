# Final Frontier

A space simulation game built with Godot 4.

## Status

`alpha_0.2` — Sim Core & Map Toolkit complete.

## Architecture

### Sim Core
Deterministic orbital simulation for all celestial bodies. Supports four motion models: circular orbits, Keplerian ellipses, Lagrange points, and fixed positions. A physics clock drives the update loop with configurable time scaling.

### Map Toolkit
A collection of view-agnostic, reusable components for map rendering. Handles coordinate transformation, zoom-based visibility filtering (scopes), and rendering of bodies, orbits, asteroid belts, zones, and grids.

## Docs

- [`docs/SIM_CORE.md`](docs/SIM_CORE.md) — Simulation architecture & API reference
- [`docs/MAP_TOOLKIT.md`](docs/MAP_TOOLKIT.md) — Map Toolkit components & integration guide

## Requirements

- Godot 4.4+
