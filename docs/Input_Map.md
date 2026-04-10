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

### MV - Keyboard Input

**Navigation**

- KEY_W -> pans the map up
- KEY_S -> pans the map down
- KEY_A -> pans the map left
- KEY_D -> pans the map right

**Zoom**

- KEY_Q -> zooms the map out
- KEY_E -> zooms the map in
- KEY_1 -> set zoom level to 1
- KEY_2 -> set zoom level to 2
- KEY_3 -> set zoom level to 3
- KEY_4 -> set zoom level to 4
- KEY_5 -> set zoom level to 5

**Time Control**

- KEY_SPACE -> pause/resume time
- KEY_RIGHT -> advance time by time_step
- KEY_LEFT -> rewind time by time_step
- KEY_UP -> increase time_step
- KEY_DOWN -> decrease time_step
- KEY_F1 -> set time_step to 1
- KEY_F2 -> set time_step to 2
- KEY_F3 -> set time_step to 3
- KEY_F4 -> set time_step to 4
- KEY_F5 -> set time_step to 5

**Panel Navigation**

- KEY_ESC -> opens Main Menu
- KEY_V -> opens PlanetView (PV)
- KEY_I -> opens InfoPanel (IP)
- KEY_L -> opens AlmanacPanel (AA)
- KEY_N -> opens NavPanel (NP)

## PlanetView (PV)

### PV - Mouse Input

- Drag on planet -> rotates the planet
- Trackpad Pan -> rotates the planet

### PV - Keyboard Input

- KEY_ESC -> opens Main Menu
- KEY_V -> closes the PlanetView and returns to MapView
- KEY_L -> opens AlmanacPanel (AA)
