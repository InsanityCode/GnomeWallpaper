import sys
from PIL import Image

class Screen:
    def __init__(self, path, x, y, w, h):
        self.path = path
        self.x = x
        self.y = y
        self.w = w
        self.h = h
        self.img = Image.open(path).resize((w, h), Image.ANTIALIAS)

    def __str__(self):
        return f"Screen: path='{self.path}', x={self.x}, y={self.y}, w={self.w}, h={self.h}"

args = sys.argv[2:]

screens = []
for i in range(0, len(args), 5):
    if i + 4 < len(args):
        path = args[i]
        x = int(args[i + 1])
        y = int(args[i + 2])
        w = int(args[i + 3])
        h = int(args[i + 4])
        screens.append(Screen(path, x, y, w, h))

w = 0
h = 0
for screen in screens:
    w = max(w, screen.x + screen.w)
    h = max(h, screen.y + screen.h)

new_image = Image.new('RGB', (w, h))
for screen in screens:
    new_image.paste(screen.img, (screen.x, screen.y))

new_image.save(sys.argv[1])
