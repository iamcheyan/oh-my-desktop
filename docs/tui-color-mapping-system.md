# Terminal TUI Color Mapping System & Optimization Plan

This document outlines the color mapping system for the Theme & Appearance TUI (`omd-settings-theme-tui`). It explains the mathematical model behind mapping 24-bit true colors (RGB) down to the limited terminal palette (xterm-256), analyzes the "grayscale flattening" bug, and proposes strategies to handle all colors with high fidelity.

---

## 1. Problem Statement: The Grayscale Ramp Trap

In terminal emulators supporting 256 colors, the color palette (indices 0 to 255) is structured as follows:
1. **0 - 15**: Standard system colors (usually customized by the terminal emulator theme).
2. **16 - 231**: A 6×6×6 color cube (216 colors) where coordinates represent quantized levels: $R, G, B \in \{0, 95, 135, 175, 215, 255\}$.
3. **232 - 255**: A grayscale ramp (24 levels) from dark charcoal to near white.

When matching an arbitrary RGB color $(r, g, b)$ to the closest index using a global distance function (such as Euclidean or perceptual `redmean` distance) across the entire range `16-255`, dark or desaturated colors are frequently pulled into the **grayscale ramp (232-255)**. 

### Why this happens (e.g. Dark Green leaf):
For a dark green color $(40, 90, 45)$:
* The nearest color in the 6×6×6 cube is $(0, 95, 0)$ (index 22). The distance is dominated by the blue channel difference ($45 - 0 = 45$, squared and weighted is very high).
* The nearest level in the grayscale ramp is $(68, 68, 68)$ (index 238). The red, green, and blue differences are all small (within 10-20), leading to a much lower overall distance.
* As a result, the algorithm maps the dark green pixel to gray. When applied to a full image, this grayscale attraction flattens most colors, turning colorful wallpapers gray.

---

## 2. Color Mapping Strategies

To ensure **all colors** (reds, blues, greens, yellows, purples, oranges, and pastels) are correctly matched and preserved, we compare three strategies.

### Strategy A: Direct 6×6×6 Cube Quantization (Fast & Robust)

This strategy maps each channel directly to the nearest of the 6 levels of the xterm color cube, completely ignoring the grayscale ramp.

#### Mathematical Model:
$$r_6 = \text{round}\left(\frac{r \cdot 5}{255}\right)$$
$$g_6 = \text{round}\left(\frac{g \cdot 5}{255}\right)$$
$$b_6 = \text{round}\left(\frac{b \cdot 5}{255}\right)$$
$$\text{Index} = 16 + 36 \cdot r_6 + 6 \cdot g_6 + b_6$$

#### Python Implementation:
```python
def _rgb_to_xterm_index(r, g, b):
    r6 = round(r * 5 / 255)
    g6 = round(g * 5 / 255)
    b6 = round(b * 5 / 255)
    return 16 + 36 * r6 + 6 * g6 + b6
```

* **Pros**: Extremely fast ($O(1)$ complexity); 100% immune to the grayscale trap; guarantees that any color with a dominant channel (like green or red) preserves its hue.
* **Cons**: Because levels are fixed in a grid, colors near the boundaries (e.g., $95$ vs $135$) can occasionally jump abruptly.

---

### Strategy B: Hue-Preserving Perceptual Search (Restricted 216-Cube)

This strategy searches the **entire 216-color cube** (indices 16-231) using a perceptual color distance formula, but explicitly **excludes the grayscale ramp (232-255)**. 

#### Distance Formula (Redmean Approximation):
$$\Delta C = (2 + \frac{\bar{r}}{256}) \cdot \Delta r^2 + 4 \cdot \Delta g^2 + (2 + \frac{255 - \bar{r}}{256}) \cdot \Delta b^2$$
where $\bar{r} = \frac{r_1 + r_2}{2}$.

#### Python Implementation:
```python
def _rgb_to_xterm_index(r, g, b):
    rgb = (r, g, b)
    # Search only the 216-color cube to avoid grayscale ramp hijacking
    best = min(
        range(16, 232), 
        key=lambda index: _perceptual_dist(rgb, _xterm_rgb(index))
    )
    return best
```

* **Pros**: High fidelity. It finds the mathematically closest color in the 3D color space without the risk of grayscale flattening.
* **Cons**: Slightly slower due to linear search ($O(216)$ operations), though caching makes this negligible.

---

### Strategy C: Saturation-Boosted (Chroma-Aware) Matching

This strategy calculates the saturation (chroma) of the input color. If the color has noticeable saturation (i.e. is not neutral gray), the algorithm penalizes grayscale matches during the search, keeping the color vibrant.

#### Python Implementation:
```python
def _rgb_to_xterm_index(r, g, b):
    rgb = (r, g, b)
    # Calculate saturation/chroma
    mx = max(r, g, b)
    mn = min(r, g, b)
    chroma = mx - mn
    
    def distance(index):
        is_gray = index >= 232
        d = _perceptual_dist(rgb, _xterm_rgb(index))
        # Penalize gray matches if the input has color
        if is_gray and chroma > 15:
            d += 12000  # heavy penalty to force colored cubes
        return d

    return min(range(16, 256), key=distance)
```

* **Pros**: Uses the grayscale ramp for *actual* grays (like gray stones or pavement) but forces colors (like leaves or skies) to use the 6×6×6 color cube.
* **Cons**: Requires tuning the chroma threshold and penalty weight.

---

## 3. Comparison of Color Mapping Strategies

| Metric | Strategy A (Direct Quantization) | Strategy B (Restricted 216-Cube) | Strategy C (Chroma-Aware Search) |
|---|---|---|---|
| **Vibrancy & Hue** | High (Never flattens to gray) | High (Forced color matching) | Excellent (Vibrant colors, real grays) |
| **Grayscale Fidelity** | Medium (Uses cube grays) | Medium (Uses cube grays) | High (Uses real grayscale ramp) |
| **Complexity** | $O(1)$ (Direct math) | $O(216)$ (Linear search) | $O(240)$ (Full search + penalty) |
| **Banding Artifacts** | Noticeable in smooth gradients | Smooth transitions | Very smooth transitions |

---

## 4. Proposed Implementation Plan

For the best visual results on a wide variety of wallpapers (such as green gardens, blue skies, red sunsets, and gray cities), **Strategy B (Restricted 216-Cube)** or **Strategy C (Chroma-Aware)** is recommended.

Let us implement **Strategy C (Chroma-Aware Search)** since it provides the highest fidelity: it preserves green leaves, blue skies, and red flowers in full color, while still letting gray stones, water, and shadows utilize the high-resolution grayscale ramp for beautiful shadow detailing.

### Step-by-Step implementation:
1. Update `_rgb_to_xterm_index(r, g, b)` in `bin/omd-settings-theme-tui` to compute color saturation (chroma).
2. For indices $\ge 232$ (grayscale ramp), add a penalty to the distance if `chroma` exceeds a threshold (e.g., $15$).
3. Maintain the `_xterm_color_cache` to ensure the $O(240)$ search only runs once per unique RGB color.
