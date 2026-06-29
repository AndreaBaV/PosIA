from pathlib import Path

from PIL import Image

ROOT = Path(r"C:\Users\andyb\.cursor\projects\c-Users-andyb-ProyectosPersonales2026-POSIA\assets")
BRANDING = Path(r"C:\Users\andyb\ProyectosPersonales2026\POSIA\apps\posia_pos\assets\branding")
BRANDING.mkdir(parents=True, exist_ok=True)


def remove_white_bg(input_path: Path, output_path: Path) -> None:
    img = Image.open(input_path).convert("RGBA")
    pixels = []
    for r, g, b, a in img.getdata():
        if r > 235 and g > 235 and b > 235:
            pixels.append((255, 255, 255, 0))
        else:
            pixels.append((r, g, b, 255))
    img.putdata(pixels)
    img.save(output_path, "PNG")


def square_icon(input_path: Path, output_path: Path, size: int = 1024) -> None:
    img = Image.open(input_path).convert("RGBA")
    img.thumbnail((size, size), Image.Resampling.LANCZOS)
    canvas = Image.new("RGBA", (size, size), (255, 255, 255, 0))
    offset = ((size - img.width) // 2, (size - img.height) // 2)
    canvas.paste(img, offset, img)
    canvas.save(output_path, "PNG")


def ticket_logo(input_path: Path, output_path: Path, width: int = 384) -> None:
    img = Image.open(input_path).convert("RGBA")
    ratio = width / img.width
    height = max(1, int(img.height * ratio))
    img = img.resize((width, height), Image.Resampling.LANCZOS)
    img.save(output_path, "PNG")


remove_white_bg(ROOT / "la_fortuna_abarrotes_logo.png", BRANDING / "logo_la_fortuna.png")
remove_white_bg(ROOT / "la_fortuna_mark_abarrotes.png", BRANDING / "logo_marca.png")
square_icon(BRANDING / "logo_marca.png", BRANDING / "app_icon.png")
ticket_logo(BRANDING / "logo_la_fortuna.png", BRANDING / "logo_ticket.png", width=384)

print("Assets listos en", BRANDING)
