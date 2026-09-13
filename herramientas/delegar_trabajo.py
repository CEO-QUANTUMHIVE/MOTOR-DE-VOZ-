"""Delegador portable del CEO local hacia la cola durable de QuantumCore."""

from __future__ import annotations

import argparse
import json
import os
import subprocess
import sys
from pathlib import Path


def encontrar_quantumcore(raiz_departamento: Path) -> Path:
    declarada = os.environ.get("QUANTUMCORE_RUTA")
    candidatos = [Path(declarada)] if declarada else []
    candidatos.extend(
        [
            raiz_departamento.parent / "quantumcore-limpio",
            raiz_departamento.parent / "QuantumCore",
        ]
    )
    for candidato in candidatos:
        delegador = candidato / "herramientas" / "delegar.py"
        if delegador.is_file():
            return candidato.resolve()
    raise SystemExit(
        "No se encontró QuantumCore. Definí QUANTUMCORE_RUTA o ubicá "
        "quantumcore-limpio junto a este repositorio."
    )


def main() -> None:
    raiz = Path(__file__).resolve().parents[1]
    manifiesto = json.loads(
        (raiz / ".quantumhive" / "departamento.json").read_text(encoding="utf-8")
    )
    codigo = manifiesto["departamento"]["codigo"]

    analizador = argparse.ArgumentParser(
        description="Delega un trabajo al pool del CEO departamental."
    )
    analizador.add_argument("titulo")
    analizador.add_argument("--objetivo", required=True)
    analizador.add_argument("--resultado", required=True)
    analizador.add_argument(
        "--tipo", choices=("liviano", "pesado", "pruebas"), default="liviano"
    )
    analizador.add_argument("--solo-vista-previa", action="store_true")
    argumentos = analizador.parse_args()

    if argumentos.solo_vista_previa:
        print(
            f"Vista previa: se delegaría [{argumentos.titulo}] al carril "
            f"[{argumentos.tipo}] de {codigo}."
        )
        return

    quantumcore = encontrar_quantumcore(raiz)
    comando = [
        sys.executable,
        str(quantumcore / "herramientas" / "delegar.py"),
        codigo,
        argumentos.titulo,
        "--objetivo",
        argumentos.objetivo,
        "--resultado",
        argumentos.resultado,
        "--tipo",
        argumentos.tipo,
    ]
    raise SystemExit(subprocess.run(comando, cwd=quantumcore, check=False).returncode)


if __name__ == "__main__":
    main()
