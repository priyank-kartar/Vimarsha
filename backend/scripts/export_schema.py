"""Export the ChapterBundle JSON Schema to /shared for the Flutter client."""
from __future__ import annotations

import json
from pathlib import Path

from vimarsha.models import ChapterBundle


def main() -> None:
    schema = ChapterBundle.model_json_schema(by_alias=True)
    out = Path(__file__).resolve().parents[2] / "shared" / "bundle.schema.json"
    out.parent.mkdir(parents=True, exist_ok=True)
    out.write_text(json.dumps(schema, indent=2) + "\n")
    print(f"wrote {out}")


if __name__ == "__main__":
    main()
