# 🧩 two_dimensional_grid

A highly customizable **two-dimensional snapping grid** widget for Flutter.
Designed for use cases where you need **precise navigation**, **snapping behavior**, and **focus scaling** for individual items in a grid — perfect for media libraries, galleries, or interactive dashboards.

---

## ✨ Features

* 🔄 **2D snapping navigation** — swipe vertically or horizontally to move focus.
* 🎯 **Focus awareness** — notifies which item is currently centered via a `ValueListenable<int>`.
* 🖱️ **Tap to snap** — built-in `snapToCenter` callback passed to the item builder.
* 🔍 **Animated zoom ("jump") effect** — configurable `scale` and `scaleJump`.
* ⚡ **Smooth pan + scale animation** — handled by a single `AnimationController`.
* ↔️ **RTL display support** — visual ordering is mirrored while internal snapping uses stable positional indices (fixes incorrect center/visual mismatch for RTL).
* 🎛️ **Per-axis snap thresholds** — `snapThresholdX` and `snapThresholdY` let you control how many pixels must be dragged on each axis before a snap occurs.
* ✋ **Simultaneous X/Y dragging** — pointer-based input processing so the user can drag diagonally and trigger both horizontal and vertical snaps while dragging.

---

## 📦 Installation

Add the package to your `pubspec.yaml`:

```yaml
dependencies:
  two_dimensional_grid: ^0.0.2
```

Then import it:

```dart
import 'package:two_dimensional_grid/two_dimensional_grid.dart';
```

## 🚀 Usage

```dart
TwoDimensionalGrid(
  count: 100,
  crossAxisCount: 10,
  itemWidth: 120,
  itemHeight: 180,
  spacing: 6,
  scale: 1.6,
  scaleJump: 0.3,
  // new options
  rtl: true,
  snapThresholdX: 100.0,
  snapThresholdY: 100.0,
  enableImmediateSnapAnimation: true,
  builder: (ctx, index, isCenter, snapToCenter) { /* ... */ },
)
```

> Notes: `index` passed to the `builder` is the **display index** (mirrored when `rtl=true`) so visual labels remain intuitive for RTL languages while internal snapping operates on fixed positional indices.

---

## ⚙️ API

| Parameter                      | Type                        | Default | Description                                                                                                                          |
| ------------------------------ | --------------------------- | ------- | ------------------------------------------------------------------------------------------------------------------------------------ |
| `count`                        | `int`                       | –       | Total number of items in the grid.                                                                                                   |
| `builder`                      | `TwoDimensionalItemBuilder` | –       | Item builder with `(context, index, isCenter, snapToCenter)` signature. `index` is the display index (mirrored in RTL).              |
| `crossAxisCount`               | `int`                       | `6`     | Number of items per row.                                                                                                             |
| `itemWidth`                    | `double`                    | `200`   | Item width.                                                                                                                          |
| `itemHeight`                   | `double`                    | `260`   | Item height.                                                                                                                         |
| `spacing`                      | `double`                    | `4`     | Space between items.                                                                                                                 |
| `padding`                      | `double`                    | `4`     | Grid padding.                                                                                                                        |
| `scale`                        | `double`                    | `1.4`   | Base zoom scale when item is centered.                                                                                               |
| `scaleJump`                    | `double`                    | `0.2`   | Extra zoom "jump" when snapping to an item.                                                                                          |
| `animation` | `bool`                      | `true`  | If `true`, snapping uses the built-in animated scale+pan jump. If `false`, snapping sets the matrix immediately (no jump animation). |
| `animationDuration`            | `Duration`                  | `300ms` | Total duration of snap + jump animation.                                                                                             |
| `rtl`                          | `bool`                      | `false` | Mirror visual ordering for RTL while keeping internal positional snapping stable.                                                    |
| `snapThresholdX`               | `double`                    | `50.0` | Pixels to drag horizontally before a horizontal snap occurs. Set `0` to disable.                                                     |
| `snapThresholdY`               | `double`                    | `100.0` | Pixels to drag vertically before a vertical snap occurs. Set `0` to disable.                                                         |

---

## 🔧 Behavior changes (important)

1. **RTL correctness**: visual labels are now provided with a mirrored `index` while internal snapping, centering calculations, and the `snapToCenter` callback operate on stable positional indices. This prevents the case where tapping a visually shown item centers a different logical tile.

2. **Per-axis thresholds**: `snapThresholdX` and `snapThresholdY` control how many pixels must be dragged on the respective axis before a snap happens. This enables fine-grained control (e.g., bigger horizontal threshold than vertical).

3. **Simultaneous X/Y dragging**: pointer-based input processing allows diagonal drags to trigger both horizontal and vertical snaps during the drag (not only on drag end). This removes the previous limitation where moving on one axis would block movement on the other.

4. **Tap behavior**: `snapToCenter` passed to item builder always snaps based on the tile's positional index (not the mirrored display index). Use the `index` argument for visual labels; call the provided `snapToCenter` to center the tapped tile.

---

## 🎯 When to Use

* Photo galleries or video thumbnails.
* Product catalogs.
* Selectors for maps, emojis, avatars.
* Any interface where the current selection matters and should be visually emphasized.

## 💡 Notes

* Designed for portrait orientation by default.
* Pan gestures are fully controlled — no free scrolling.
* Best suited for
