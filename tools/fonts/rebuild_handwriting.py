"""프로젝트 벨카 - 인물별 손글씨 글꼴 다시 만들기 (기본 디자인 0.2)

게임 전체 텍스트(data/ · scripts/ · scenes/)에 나오는 글자만 남긴 손글씨 글꼴 7종을 만든다.
원본 글꼴은 크기가 커서(Hi Melody · Gamja Flower 각 12MB) 저장소에 넣지 않는다.
대사·필기를 새로 쓰면 이 도구를 다시 돌려 빠진 글자가 없게 한다.

준비: fonttools 설치 (python -m pip install fonttools)
원본: Google Fonts 공식 저장소(https://github.com/google/fonts/tree/main/ofl)에서 받아 한 폴더에 둔다.
      SingleDay · PoorStory · HiMelody · GamjaFlower 는 --source-dir 에서,
      NanumBrushScript · NanumPenScript · Gaegu 는 assets/fonts/ 에 이미 있는 원본을 쓴다.
실행 (저장소 루트에서):
      python tools/fonts/rebuild_handwriting.py --source-dir E:/fonts-original
결과: assets/fonts/hand/<인물>-Hand.ttf (내부 이름 PVHand<인물>) + hand_manifest.json
원본을 지우지 않는다. 라이선스(OFL) 원문은 assets/fonts/hand/licenses/ 에 함께 둔다.
"""
from pathlib import Path
import argparse
import json
import sys

from fontTools.ttLib import TTFont
from fontTools import subset

ROOT = Path(__file__).resolve().parents[2]
OUTPUT = ROOT / "assets" / "fonts" / "hand"
## (인물, 원본 파일, 원본 이름) — 디자인 0.2 인물별 손글씨
FACES = [
    ("Sabi", "SingleDay-Regular.ttf", "Single Day"),
    ("Shamu", "NanumBrushScript-Regular.ttf", "Nanum Brush Script"),
    ("Kwon", "PoorStory-Regular.ttf", "Poor Story"),
    ("Baek", "HiMelody-Regular.ttf", "Hi Melody"),
    ("Seo", "GamjaFlower-Regular.ttf", "Gamja Flower"),
    ("Yu", "NanumPenScript-Regular.ttf", "Nanum Pen Script"),
    ("Han", "Gaegu-Regular.ttf", "Gaegu"),
]
TEXT_DIRS = ["data", "scripts", "scenes"]
TEXT_SUFFIXES = {".json", ".gd", ".tscn", ".tres", ".txt", ".md", ".csv"}
EXTRA = "".join(chr(i) for i in range(32, 127)) + "…·—–→←↑↓✓□■○●△▷《》「」『』〈〉※～"


def find_source(name: str, source_dir: Path | None) -> Path | None:
    for d in ([source_dir] if source_dir else []) + [ROOT / "assets" / "fonts"]:
        if (d / name).is_file():
            return d / name
    return None


def corpus() -> tuple[str, int]:
    files = [f for d in TEXT_DIRS for f in (ROOT / d).rglob("*") if f.is_file() and f.suffix.lower() in TEXT_SUFFIXES]
    text = "".join(f.read_text(encoding="utf-8-sig", errors="ignore") for f in files)
    return "".join(sorted(set(text + EXTRA))), len(files)


def main() -> None:
    p = argparse.ArgumentParser()
    p.add_argument("--source-dir", type=Path, help="원본 손글씨 글꼴 폴더")
    a = p.parse_args()
    sources = {}
    for person, name, _ in FACES:
        path = find_source(name, a.source_dir)
        if path is None:
            sys.exit(f"원본 글꼴이 없습니다: {name} (--source-dir 를 확인하세요). 기존 글꼴은 그대로 둡니다.")
        sources[person] = path
    text, file_count = corpus()
    OUTPUT.mkdir(parents=True, exist_ok=True)
    result = []
    for person, name, display in FACES:
        font = TTFont(sources[person])
        supported = set(font.getBestCmap())
        missing = "".join(c for c in text if ord(c) > 127 and not c.isspace() and ord(c) not in supported)
        opt = subset.Options()
        opt.name_IDs = ["*"]
        opt.name_languages = ["*"]
        opt.name_legacy = True
        sub = subset.Subsetter(options=opt)
        sub.populate(text=text)
        sub.subset(font)
        family = "PVHand" + person
        names = {1: family, 2: "Regular", 3: family + "-GameSubset", 4: family + " Regular", 6: family + "-Regular", 16: family, 17: "Regular"}
        for record in font["name"].names:
            if record.nameID in names:
                record.string = names[record.nameID].encode(record.getEncoding(), errors="replace")
        target = OUTPUT / f"{person}-Hand.ttf"
        font.save(target)
        result.append({"file": target.name, "family": family, "source": name, "source_name": display,
                       "glyphs": len(font.getGlyphOrder()), "bytes": target.stat().st_size,
                       "missing_in_original": missing})
    manifest = {"text_files": file_count, "characters": len(text), "fonts": result}
    (OUTPUT / "hand_manifest.json").write_text(json.dumps(manifest, ensure_ascii=False, indent=2), encoding="utf-8")
    for r in result:
        print(f"{r['file']:16} {r['glyphs']:5} 글자  {r['bytes'] // 1024:5} KB  원본에 없는 글자 {len(r['missing_in_original'])}개")


if __name__ == "__main__":
    main()
