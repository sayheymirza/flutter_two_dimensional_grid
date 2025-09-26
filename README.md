# 🧩 two_dimensional_grid

A highly customizable **two-dimensional snapping grid** widget for Flutter.  
Designed for use cases where you need **precise navigation**, **snapping behavior**, and **focus scaling** for individual items in a grid — perfect for media libraries, galleries, or interactive dashboards.

---

## ✨ Features

- 🔄 **2D snapping navigation** — swipe vertically or horizontally to move focus.
- 🎯 **Focus awareness** — notifies which item is currently centered.
- 🖱️ **Tap to snap** — built-in `snapToCenter` callback.
- 🔍 **Animated zoom ("jump") effect** — configurable `scale` and `scaleJump`.
- ⚡ **Smooth pan + scale animation** — handled by a single `AnimationController`.
- 📱 **Edge-to-edge immersive layout** — status/navigation bars made transparent.

---

## 📦 Installation

Add the package to your `pubspec.yaml`:

```yaml
dependencies:
  two_dimensional_grid: ^0.0.1
```

Then import it:

```dart
import 'package:two_dimensional_grid/two_dimensional_grid.dart';
```

## 🚀 Usage

```dart
import 'package:flutter/material.dart';
import 'package:two_dimensional_grid/two_dimensional_grid.dart';

class ExamplePage extends StatelessWidget {
  const ExamplePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: TwoDimensionalGrid(
        count: 100,
        crossAxisCount: 10,
        itemWidth: 120,
        itemHeight: 180,
        spacing: 6,
        scale: 1.6,
        scaleJump: 0.3,
        builder: (ctx, index, isCenter, snapToCenter) {
          return GestureDetector(
            onTap: snapToCenter,
            child: AnimatedScale(
              duration: const Duration(milliseconds: 150),
              scale: isCenter ? 1.0 : 0.9,
              child: Container(
                decoration: BoxDecoration(
                  color: isCenter ? Colors.white : Colors.grey.shade800,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Center(
                  child: Text(
                    '$index',
                    style: TextStyle(
                      color: isCenter ? Colors.black : Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
```

## ⚙️ API
| Parameter           | Type                        | Default | Description                                                             |
| ------------------- | --------------------------- | ------- | ----------------------------------------------------------------------- |
| `count`             | `int`                       | –       | Total number of items in the grid.                                      |
| `builder`           | `TwoDimensionalItemBuilder` | –       | Item builder with `(context, index, isCenter, snapToCenter)` signature. |
| `crossAxisCount`    | `int`                       | `6`     | Number of items per row.                                                |
| `itemWidth`         | `double`                    | `200`   | Item width.                                                             |
| `itemHeight`        | `double`                    | `260`   | Item height.                                                            |
| `spacing`           | `double`                    | `4`     | Space between items.                                                    |
| `padding`           | `double`                    | `4`     | Grid padding.                                                           |
| `scale`             | `double`                    | `1.4`   | Base zoom scale when item is centered.                                  |
| `scaleJump`         | `double`                    | `0.2`   | Extra zoom "jump" when snapping to an item.                             |
| `animationDuration` | `Duration`                  | `300ms` | Total duration of snap + jump animation.                                |

## 🎯 When to Use
- Photo galleries or video thumbnails.
- Product catalogs.
- Selectors for maps, emojis, avatars.
- Any interface where the current selection matters and should be visually emphasized.

## 💡 Notes
- Designed for portrait orientation by default.
- Pan gestures are fully controlled — no free scrolling.
- Best suited for grids with a moderate number of items (e.g. ≤ 500) because each snap computes nearest item distances.

## 📌 Example Behavior
- Swipe up/down → focus moves one row.
- Swipe left/right → focus moves one column.
- Tap item → smoothly animates into center with a jump effect.

## 📄 License
This project is licensed under the terms of the **nolicense** license.