import json
import sys
from pathlib import Path

from pypdf import PdfReader


def main() -> int:
    if len(sys.argv) != 2:
        raise SystemExit("usage: extract_pdf_pages.py <pdf_path>")

    pdf_path = Path(sys.argv[1])
    reader = PdfReader(str(pdf_path))

    pages = []
    for index, page in enumerate(reader.pages, start=1):
      text = page.extract_text() or ""
      pages.append(
          {
              "page": index,
              "text": text,
          }
      )

    json.dump({"pages": pages}, sys.stdout, ensure_ascii=False)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
