"""Read alpha silhouettes only; never modify artwork pixels."""
import json
from pathlib import Path
import cv2
import numpy as np
from PIL import Image

root = Path(__file__).resolve().parents[2]
report = {}
for name, relative in {
    'shipping': 'assets/art/presentation/citizen-lineup-business.png',
    'candidate': 'docs/commuter-review/commuter-candidate-not-shipping.png',
}.items():
    pixels = np.asarray(Image.open(root / relative).convert('RGBA'))
    stats = cv2.connectedComponentsWithStats((pixels[:, :, 3] > 90).astype(np.uint8), 8)[2][1:]
    bodies = [list(map(int, s)) for s in stats if s[4] > 2200]
    anchors = sorted(s[1] + s[3] / 2 for s in bodies if s[0] + s[2] / 2 < pixels.shape[1] / 6)
    rows = [[] for _ in anchors]
    for s in bodies:
        rows[min(range(len(anchors)), key=lambda i: abs(anchors[i] - s[1] - s[3] / 2))].append(s)
    assert len(rows) == 10 and all(len(row) == 6 for row in rows)
    report[name] = {
        'size': [pixels.shape[1], pixels.shape[0]],
        'row_counts': [len(row) for row in rows],
        'walk_mean_height': {
            direction: round(sum(s[3] for row in rows[i*2:i*2+2] for s in row) / 12, 2)
            for i, direction in enumerate(['front', 'back', 'left', 'right'])
        },
    }
(Path(__file__).parent / 'scale-report.json').write_text(json.dumps(report, indent=2) + '\n')
print(json.dumps(report, indent=2))
