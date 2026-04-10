# Final Frontier - Input Specification

This document defines the input format for the Final Frontier game. The game screen consists of multiple panels that display different types of information. For easier reference, each panel is assigned a unique identifier. MV -> MapView, PV -> PlanetView, NP -> NavPanel, IP -> InfoPanel and AA -> AlmanacPanel.

## MapView (MV)

### MV - Mouse Input

**Navigation**

- Left click on empty space -> pans the map
- Drag on empty space -> pans the map
- Trackpad Pan -> pans the map
- Scroll wheel -> zooms the map
- Trackpad Zoom/Pinch -> zooms the map

**Marker Interaction**

- Hover Marker -> highlights the marker
- Left click on MapMarker -> pans the map to the marker
- Double left clock on marker -> opens InfoPanel (IP)
- Right click on marker -> opens context menu (pin body, show PV, show AA)
- Right click on empty space with selected marker -> deselects the marker

## PlanetView (PV)

### PV - Mouse Input

- Drag on planet -> rotates the planet
- Trackpad Pan -> rotates the planet
