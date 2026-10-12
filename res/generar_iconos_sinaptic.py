# Iconos propios de Sinaptic Remoto (1.5.0-5): monitor con cursor sobre el
# morado Sinaptic y el punto cian de la marca en la punta del cursor.
# Variante Cliente: el mismo monitor con un celular delante.
# Uso: python res/generar_iconos_sinaptic.py <raiz del repo>
import sys, os
from PIL import Image, ImageDraw

REPO = sys.argv[1]
MORADO = (0x63, 0x32, 0xF9, 255)
CIAN = (0x00, 0xD2, 0xFF, 255)
BLANCO = (255, 255, 255, 255)
VACIO = (0, 0, 0, 0)
SS = 4  # sobremuestreo
CURSOR = [(0, 0), (0, 100), (26, 77), (44, 116), (62, 108), (44, 70), (78, 70)]


def geometria(cliente, chico):
    """Todo en unidades de un lienzo de 512."""
    dx, dy = (-24, -20) if cliente else (0, 0)
    g = {}
    s = 52 if chico else 32
    g["trazo"] = s
    g["monitor"] = (80 + dx, 104 + dy, 432 + dx, 344 + dy, 44 if chico else 36)
    g["cuello"] = (232 + dx, 340 + dy, 280 + dx, 396 + dy)
    mb = 76 if cliente else 88  # medio ancho del pie (en Cliente no toca el celular)
    g["base"] = (256 - mb + dx, 384 + dy, 256 + mb + dx, 420 + dy, 18)
    if chico:
        k, tx, ty, r = 1.12, 212 + dx, 170 + dy, 30
    else:
        k, tx, ty, r = 1.25, 210 + dx, 166 + dy, 22
    g["cursor"] = [(tx + x * k, ty + y * k) for x, y in CURSOR]
    g["punto"] = (tx, ty, r)
    if cliente:
        g["celular"] = (332, 248, 444, 444, 22)
        g["hueco"] = 18
        g["pantalla_cel"] = (332 + 18, 248 + 24, 444 - 18, 444 - 34, 6)
    return g


def dibujar(d, f, ox, oy, cliente=False, chico=False, fondo=MORADO, blanco=BLANCO, cian=CIAN):
    """Dibuja el simbolo. f = pixeles por unidad; (ox, oy) desplazamiento.
    fondo: color de los huecos (VACIO para fondo transparente)."""
    g = geometria(cliente, chico)
    P = lambda x, y: (ox + x * f, oy + y * f)

    x0, y0, x1, y1, r = g["monitor"]
    d.rounded_rectangle([*P(x0, y0), *P(x1, y1)], radius=r * f, outline=blanco, width=max(1, round(g["trazo"] * f)))
    x0, y0, x1, y1 = g["cuello"]
    d.rectangle([*P(x0, y0), *P(x1, y1)], fill=blanco)
    x0, y0, x1, y1, r = g["base"]
    d.rounded_rectangle([*P(x0, y0), *P(x1, y1)], radius=r * f, fill=blanco)
    d.polygon([P(x, y) for x, y in g["cursor"]], fill=blanco)
    px, py, r = g["punto"]
    d.ellipse([*P(px - r, py - r), *P(px + r, py + r)], fill=cian or blanco)

    if cliente:
        x0, y0, x1, y1, r = g["celular"]
        h = g["hueco"]
        d.rounded_rectangle([*P(x0 - h, y0 - h), *P(x1 + h, y1 + h)], radius=(r + h) * f, fill=fondo)
        d.rounded_rectangle([*P(x0, y0), *P(x1, y1)], radius=r * f, fill=blanco)
        x0, y0, x1, y1, r = g["pantalla_cel"]
        d.rounded_rectangle([*P(x0, y0), *P(x1, y1)], radius=r * f, fill=fondo)


def lienzo(n):
    return Image.new("RGBA", (n * SS, n * SS), VACIO)


def reducir(img, n):
    return img.resize((n, n), Image.LANCZOS)


def completo(n, cliente=False, forma="cuadrado"):
    """Fondo morado con el simbolo, como assets/icon.svg."""
    N = n * SS
    img = lienzo(n)
    d = ImageDraw.Draw(img)
    if forma == "circulo":
        d.ellipse([0, 0, N - 1, N - 1], fill=MORADO)
    else:
        d.rounded_rectangle([0, 0, N - 1, N - 1], radius=112 / 512 * N, fill=MORADO)
    f = N / 512
    if forma == "circulo":
        # el circulo recorta las esquinas: el simbolo un poco mas chico
        k = 0.86
        dibujar(d, f * k, N * (1 - k) / 2, N * (1 - k) / 2, cliente, n <= 24)
    else:
        dibujar(d, f, 0, 0, cliente, n <= 24)
    return reducir(img, n)


def suelto(n, rel, cliente=False, cian=CIAN, chico=False):
    """Solo el simbolo, sin fondo, con el marco de 512 ocupando rel del lienzo."""
    N = n * SS
    img = lienzo(n)
    d = ImageDraw.Draw(img)
    f = N * rel / 512
    o = N * (1 - rel) / 2
    dibujar(d, f, o, o, cliente, chico, fondo=VACIO, cian=cian)
    return reducir(img, n)


def ico(ruta, tamanos, cliente=False):
    imgs = [completo(t, cliente) for t in tamanos]
    imgs[-1].save(ruta, sizes=[(t, t) for t in tamanos], append_images=imgs[:-1])


def svg(cliente=False):
    g = geometria(cliente, False)
    x0, y0, x1, y1, r = g["monitor"]
    s = g["trazo"]
    h = s / 2
    pts = " ".join(f"{x:g},{y:g}" for x, y in g["cursor"])
    px, py, pr = g["punto"]
    cx0, cy0, cx1, cy1 = g["cuello"]
    bx0, by0, bx1, by1, br = g["base"]
    return f"""<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 512 512">
  <rect width="512" height="512" rx="112" fill="#6332f9"/>
  <rect x="{x0 + h:g}" y="{y0 + h:g}" width="{x1 - x0 - s:g}" height="{y1 - y0 - s:g}" rx="{r - h:g}" fill="none" stroke="#fff" stroke-width="{s}"/>
  <rect x="{cx0}" y="{cy0}" width="{cx1 - cx0}" height="{cy1 - cy0}" fill="#fff"/>
  <rect x="{bx0}" y="{by0}" width="{bx1 - bx0}" height="{by1 - by0}" rx="{br}" fill="#fff"/>
  <polygon points="{pts}" fill="#fff"/>
  <circle cx="{px}" cy="{py}" r="{pr}" fill="#00d2ff"/>
</svg>
"""


# ---- Windows y escritorio ----
res = os.path.join(REPO, "res")
completo(1024).save(os.path.join(res, "icon.png"))
completo(256).save(os.path.join(res, "128x128@2x.png"))
for n in (32, 64, 128):
    completo(n).save(os.path.join(res, f"{n}x{n}.png"))
TODOS = [16, 24, 32, 48, 64, 128, 256]
ico(os.path.join(res, "icon.ico"), TODOS)
ico(os.path.join(res, "tray-icon.ico"), [16, 24, 32, 48])
ico(os.path.join(REPO, "flutter", "windows", "runner", "resources", "app_icon.ico"), TODOS)

# ---- logo dentro de la app ----
with open(os.path.join(REPO, "flutter", "assets", "icon.svg"), "w", encoding="utf-8", newline="\n") as fh:
    fh.write(svg())

# ---- Android: completa en main, Cliente en src/cliente (lo sobrescribe) ----
DENS = (("mdpi", 48), ("hdpi", 72), ("xhdpi", 96), ("xxhdpi", 144), ("xxxhdpi", 192))
for variante, cliente in (("main", False), ("cliente", True)):
    base_res = os.path.join(REPO, "flutter", "android", "app", "src", variante, "res")
    for nombre, base in DENS:
        carpeta = os.path.join(base_res, f"mipmap-{nombre}")
        os.makedirs(carpeta, exist_ok=True)
        completo(base, cliente).save(os.path.join(carpeta, "ic_launcher.png"))
        completo(base, cliente, "circulo").save(os.path.join(carpeta, "ic_launcher_round.png"))
        # primer plano adaptable: lienzo de 108dp, simbolo dentro de la zona segura (66dp)
        suelto(base * 108 // 48, 60 / 108, cliente).save(os.path.join(carpeta, "ic_launcher_foreground.png"))
        if not cliente:
            # notificacion: silueta blanca del monitor (Android solo usa el alfa)
            suelto(base // 2, 1.0, cian=None, chico=True).convert("LA").save(os.path.join(carpeta, "ic_stat_logo.png"))

# ---- vistas previas ----
docs = os.path.join(REPO, "docs")
os.makedirs(docs, exist_ok=True)
completo(512).save(os.path.join(docs, "icono-remoto-completo.png"))
completo(512, True).save(os.path.join(docs, "icono-remoto-cliente.png"))


def hoja():
    tam = [16, 24, 32, 48, 64, 128]
    W = 900
    filas = []
    for fondo in ((255, 255, 255, 255), (32, 32, 36, 255)):
        for cliente in (False, True):
            filas.append((fondo, cliente))
    alto_fila = 128 + 40
    H = alto_fila * len(filas) + 2 * 230 + 40
    img = Image.new("RGBA", (W, H), (240, 240, 240, 255))
    d = ImageDraw.Draw(img)
    y = 20
    for fondo, cliente in filas:
        d.rectangle([0, y - 20, W, y + alto_fila - 20], fill=fondo)
        x = 40
        for t in tam:
            ic = completo(t, cliente)
            img.alpha_composite(ic, (x, y + (128 - t) // 2))
            x += t + 24
        y += alto_fila
    # Android: cuadrado, redondo, adaptable (circulo y squircle), notificacion
    for fondo in ((255, 255, 255, 255), (32, 32, 36, 255)):
        d.rectangle([0, y - 20, W, y + 210], fill=fondo)
        x = 40
        for cliente in (False, True):
            for forma in ("cuadrado", "circulo"):
                img.alpha_composite(completo(96, cliente, forma), (x, y))
                x += 110
            # adaptable con mascara circular
            fg = suelto(96 * 108 // 72, 60 / 108, cliente)
            capa = Image.new("RGBA", fg.size, MORADO)
            capa.alpha_composite(fg)
            m = Image.new("L", fg.size, 0)
            c0 = round(fg.size[0] * 18 / 108); ImageDraw.Draw(m).ellipse([c0, c0, fg.size[0] - 1 - c0, fg.size[1] - 1 - c0], fill=255)
            capa.putalpha(m)
            lado = capa.size[0]; c = round(lado * 18 / 108)
            capa = capa.crop((c, c, lado - c, lado - c)).resize((96, 96), Image.LANCZOS)
            img.alpha_composite(capa, (x, y))
            x += 130
        # notificacion (silueta), en 24 y 48
        for t in (24, 48):
            n = suelto(t, 1.0, cian=None, chico=True)
            tinte = (40, 40, 40, 255) if fondo[0] > 128 else (255, 255, 255, 255)
            plano = Image.new("RGBA", n.size, tinte)
            plano.putalpha(n.getchannel("A"))
            img.alpha_composite(plano, (x, y + (96 - t) // 2))
            x += t + 20
        y += 230
    return img


hoja().save(os.path.join(docs, "icono-remoto-tamanos.png"))
print("listo")
