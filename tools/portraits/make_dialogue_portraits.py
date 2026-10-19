"""프로젝트 벨카 - 대화창 전용 초상화 만들기

원본(1254px 안팎)을 대화창 초상화 액자 비율(224x214의 2배)로 줄이고 구도를 맞춘 사본을
assets/characters/portraits/dialogue/ 에 만든다. 원본은 건드리지 않는다.
- 사비 · 샤무: 캐릭터/표정/ 의 원본을 읽는다 (파일 이름이 달라서 아래 EXPRESSIONS 로 게임 이름에 대응).
- 그 밖의 인물: assets/characters/portraits/*.png

- 원본이 커서(장당 1254x1254 무손실) 처음 쓰일 때 읽는 데 장당 0.05~0.4초가 걸려 대화창이 뜨기 전에
  화면이 멈췄다. 액자 크기의 2배로 줄여 두면 거의 바로 읽힌다.
- 예전에는 액자를 꽉 채우려고 그림을 키워서, 세로로 긴 사비 그림은 아래(어깨)가 잘려 얼굴만 보였다.
  이제 그림 전체가 액자 안에 들어가게 줄여 머리부터 어깨까지 하나도 잘리지 않는다.
  그림이 액자 폭보다 좁아지는 쪽은 양옆을 부드럽게 흐려 액자 바탕(어두운색)에 녹인다.

실행: python3 tools/portraits/make_dialogue_portraits.py  (그 뒤 Godot 에서 임포트)
"""
import glob
import os

from PIL import Image

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
SRC = os.path.join(ROOT, "assets", "characters", "portraits")
DST = os.path.join(SRC, "dialogue")
EXPRESSIONS_DIR = os.path.join(ROOT, "캐릭터", "표정")
# 게임 초상화 이름 → 캐릭터/표정/ 원본 파일 이름 (원본 철자 그대로)
EXPRESSIONS = {
    "sabi_determined.png": "Sabi_Determined.png",
    "sabi_embarrassed.png": "Sabi_Embarassed.png",
    "sabi_gentle_smile.png": "Sabi_Gentle_Smile.png",
    "sabi_neutral.png": "Sabi_Neutral.png",
    "sabi_sad.png": "Sabi_Sad.png",
    "sabi_serious.png": "Sabi_Serious.png",
    "sabi_surprised.png": "Sabi_Surprised.png",
    "sabi_worried.png": "Sabi_Worried.png",
    "shamu_annoyed.png": "Shamu_Annoyed.png",
    "shamu_cheerful_grin.png": "Shamu_Cheerful_grin.png",
    "shamu_determined.png": "Shamu_Determined.png",
    "shamu_neutral.png": "Shamu_Neitral.png",
    "shamu_sad.png": "Shamu_Sad.png",
    "shamu_serious.png": "Shamu_Seriout.png",
    "shamu_smug.png": "Shamu_Smug.png",
    "shamu_surprised.png": "Shamu_Surprised.png",
}
# DialogueBox.PORTRAIT_W / PORTRAIT_H 의 2배
FRAME_W, FRAME_H = 448, 428
# 양옆이 비면 흐리게 녹이는 폭 (픽셀)
FEATHER = 36


def make(path, name=None):
    name = name or os.path.basename(path)
    im = Image.open(path).convert("RGBA")
    # 그림 전체가 액자 안에 들어가는 배율 (잘리는 곳이 없다)
    scale = min(FRAME_W / im.width, FRAME_H / im.height)
    w, h = round(im.width * scale), round(im.height * scale)
    small = im.resize((w, h), Image.LANCZOS)
    x = (FRAME_W - w) // 2
    y = FRAME_H - h  # 아래에 붙인다 (몸이 액자 아래로 이어지게)
    if w < FRAME_W:
        # 양옆 가장자리를 투명하게 흐린다 (그림이 액자 폭보다 좁을 때 잘린 세로선이 보이지 않게)
        alpha = small.getchannel("A")
        px = alpha.load()
        for cx in range(min(FEATHER, w // 2)):
            k = cx / FEATHER
            for cy in range(h):
                px[cx, cy] = int(px[cx, cy] * k)
                px[w - 1 - cx, cy] = int(px[w - 1 - cx, cy] * k)
        small.putalpha(alpha)
    out = Image.new("RGBA", (FRAME_W, FRAME_H), (0, 0, 0, 0))
    out.alpha_composite(small, (x, y))
    out.save(os.path.join(DST, name), optimize=True)
    return name, scale


def main():
    os.makedirs(DST, exist_ok=True)
    jobs = [(os.path.join(EXPRESSIONS_DIR, src), name) for name, src in EXPRESSIONS.items()]
    jobs += [(path, os.path.basename(path)) for path in sorted(glob.glob(os.path.join(SRC, "*.png")))]
    for path, out_name in jobs:
        name, scale = make(path, out_name)
        print("wrote dialogue/%s (scale %.3f)" % (name, scale))


if __name__ == "__main__":
    main()
