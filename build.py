#!/usr/bin/env python3
"""
build.py — Genera un archivo zip listo para CurseForge del addon aoe_dk.

Uso:
    python build.py            # lee la versión desde aoe_dk.toc
    python build.py 1.2.0      # versión personalizada

Salida: dist/aoe_dk-<version>.zip
"""

import os
import re
import sys
import zipfile
from pathlib import Path

# ---------------------------------------------------------------------------
# Configuración
# ---------------------------------------------------------------------------
ADDON_NAME = "aoe_dk"
ADDON_DIR  = Path(__file__).parent.resolve()
DIST_DIR   = ADDON_DIR / "releases"

# Archivos y carpetas a incluir (relativo a ADDON_DIR)
INCLUDE = [
    "aoe_dk.lua",
    "aoe_dk.toc",
    "CHANGELOG.md",
    "README.md",
]

# Patrones a excluir siempre (por nombre de archivo)
EXCLUIR_NOMBRES = {
    "build.py",
    ".DS_Store",
    "Thumbs.db",
}

EXCLUIR_EXT = {".pyc", ".pyo"}

# ---------------------------------------------------------------------------
# Funciones auxiliares
# ---------------------------------------------------------------------------
def leer_version_toc(toc_path: Path) -> str:
    """Extrae ## Version: x.y.z del archivo .toc."""
    texto = toc_path.read_text(encoding="utf-8")
    match = re.search(r"^##\s*Version:\s*(.+)$", texto, re.MULTILINE)
    if not match:
        raise ValueError(f"No se encontró el campo '## Version:' en {toc_path}")
    return match.group(1).strip()


def incluir_archivo(path: Path) -> bool:
    if path.name in EXCLUIR_NOMBRES:
        return False
    if path.suffix in EXCLUIR_EXT:
        return False
    return True

# ---------------------------------------------------------------------------
# Principal
# ---------------------------------------------------------------------------
def build(version: str | None = None):
    toc_path = ADDON_DIR / f"{ADDON_NAME}.toc"
    if not toc_path.exists():
        sys.exit(f"ERROR: {toc_path} no encontrado — ejecuta este script desde la carpeta del addon.")

    if version is None:
        version = leer_version_toc(toc_path)

    zip_name = f"release-{version}.zip"
    DIST_DIR.mkdir(exist_ok=True)
    zip_path = DIST_DIR / zip_name

    # CurseForge espera los archivos dentro de una carpeta con el nombre del addon
    prefijo = f"{ADDON_NAME}/"

    with zipfile.ZipFile(zip_path, "w", compression=zipfile.ZIP_DEFLATED) as zf:
        for entry in INCLUDE:
            src = ADDON_DIR / entry
            if not src.exists():
                print(f"  AVISO: {entry} no encontrado, se omite.")
                continue
            if src.is_dir():
                for file in sorted(src.rglob("*")):
                    if file.is_file() and incluir_archivo(file):
                        arcname = prefijo + file.relative_to(ADDON_DIR).as_posix()
                        zf.write(file, arcname)
                        print(f"  + {arcname}")
            else:
                if incluir_archivo(src):
                    arcname = prefijo + src.name
                    zf.write(src, arcname)
                    print(f"  + {arcname}")

    print(f"\nPaquete generado: {zip_path}")
    print(f"Tamaño:  {zip_path.stat().st_size / 1024:.1f} KB")

if __name__ == "__main__":
    version_arg = sys.argv[1] if len(sys.argv) > 1 else None
    build(version_arg)
