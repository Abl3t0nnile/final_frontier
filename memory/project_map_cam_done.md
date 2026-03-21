---
name: MapCameraController — implementiert und integriert
description: Status der MapCameraController-Implementierung nach SPEC_map_cam_controller.md
type: project
---

MapCameraController (`game/map/toolkit/map_camera_controller.gd`) ist vollständig implementiert und in der MapTestScene (`game/map/test/map_test_scene.gd`) integriert. Testszene läuft.

**Scope des Refactors (alpha_0.3 TODO_culling_refactor.md):**
- Phase 1 (Scope-System löschen): laut Git-Status bereits erledigt (scope_config/resolver gelöscht)
- MapViewController: bereits als Node umgebaut (Phase 3 erledigt)
- MapFilterState: bereits vorhanden im `filter/`-Ordner (Phase 2 erledigt)
- MapCameraController: jetzt implementiert
- MapTestScene: integriert (Phase 5 erledigt)

**Noch offen laut TODO:**
- Phase 4: Map Settings Menü (UI) — Filter-Panel links
- Phase 6: StarChartView bauen (`star_chart_view.gd` nach SPEC_star_chart_view.md)
- Phase 7/8: Dokumentation aktualisieren

**Why:** Culling-Refactor ersetzt das alte Scope-System durch simples min_orbit_px + Viewport-Culling + MapFilterState.
**How to apply:** Nächster Schritt wahrscheinlich StarChartView oder Map Settings Panel.
