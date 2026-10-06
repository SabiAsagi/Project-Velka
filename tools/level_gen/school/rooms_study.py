# -*- coding: utf-8 -*-
"""본관 2~4층 자습실·동아리실 (가이드라인 6장, 학교_맵_상세.md 자습실·일반 동아리실). 앞(v=0) = 복도(문) 벽."""
from props_base import wall_item, shelf_along, shelf_unit, cabinet, plant, bins, bench, curtain
from props_more import office_desk, table, carrel, blinds, whiteboard_wall


def _common(ctx, notice=True):
    """모든 자습실: 감독 책상, 시계, 문제집 책장, 정수기·소형 냉장고, 프린터, 이용 안내판"""
    p, W, D = ctx.p, ctx.W, ctx.D
    office_desk(p, W / 2, 1.05, facing=1, w=1.3, items=("papers", "mug"), key="sup")
    wall_item(p, W, D, "front", W / 2, 0.32, 0.0, 0.05, 2.45, 2.77, "clock_rim")
    wall_item(p, W, D, "front", W / 2, 0.26, 0.05, 0.01, 2.48, 2.74, "clock_face")
    if notice:
        wall_item(p, W, D, "front", W / 2 + 1.2, 0.3, 0.0, 0.004, 1.3, 1.72, "paper_yellow")
    wall_item(p, W, D, "left", D - 1.2, 0.42, 0.02, 0.42, 0.0, 1.3, "purifier", collide=True)
    wall_item(p, W, D, "left", D - 1.9, 0.55, 0.02, 0.55, 0.0, 0.85, "fridge_small", collide=True)
    wall_item(p, W, D, "left", D - 2.7, 0.7, 0.02, 0.55, 0.0, 0.95, "copier", collide=True)


def study_2f(ctx):
    """2층: 6인용 긴 책상 4개(앞쪽), 분리 통로, 창가 개인석 4개, 그룹 화이트보드, 공용 교과서 책장, 얇은 밝은 커튼
    (자습실 폭 약 5.9m x 깊이 약 7.7m: 교실을 복도 쪽으로 넓히며 자습실이 좁아졌다)"""
    p, W, D = ctx.p, ctx.W, ctx.D
    _common(ctx)
    for i, (u, v) in enumerate(((W / 2 - 1.2, 2.75), (W / 2 + 1.2, 2.75), (W / 2 - 1.2, 4.55), (W / 2 + 1.2, 4.55))):
        table(p, u, v, 1.9, 0.9, 3, along="u", key="s2%d" % i)
        for k in range(2):
            p.box("paper", u - 0.5 + 0.8 * k, v, 0.3, 0.21, 0.75, 0.76)
    for i in range(4):
        u = 1.3 + (W - 2.6) * i / 3
        carrel(p, u, D - 0.62, facing=1, w=0.9, items=("books",) if i % 2 == 0 else (), key="c2%d" % i)
    whiteboard_wall(p, W, D, "right", 3.9, 2.2)
    shelf_along(p, W, D, "left", 2.9, 1.6, 0.35, 1.2, 3, 0.85, key="tb2")
    for w in ctx.windows_on("back"):
        pass
    _light_curtains(ctx)


def study_3f(ctx):
    """3층: 4인용 책상 2개 + 낮은 책장 칸막이 + 칸막이 개인석 6개, 진로 서적, 충전함, 복사기, 과제 일정"""
    p, W, D = ctx.p, ctx.W, ctx.D
    _common(ctx)
    for i, u in enumerate((W / 2 - 1.2, W / 2 + 1.2)):
        table(p, u, 2.9, 1.3, 0.9, 2, along="u", key="s3%d" % i)
    for u0, u1 in ((0.9, W / 2 - 0.7), (W / 2 + 0.7, W - 0.9)):
        shelf_unit(p, (u0 + u1) / 2, 4.3, u1 - u0, 0.35, 0.95, 2, 0.8, key="d3%d" % int(u0), front=-1)
    for block, vb in enumerate((5.9,)):
        for row, facing in ((0, -1), (1, 1)):
            # 등을 맞댄 두 줄: 앞판끼리 맞닿고 의자는 바깥쪽
            v = vb + 0.3 if facing < 0 else vb - 0.3
            for i in range(3):
                u = W / 2 + 1.2 * (i - 1)
                items = ("books", "bag") if (i + row + block) % 3 == 0 else ("number",)
                carrel(p, u, v, facing=facing, w=0.85, items=items, key="c3%d%d%d" % (block, row, i))
    shelf_along(p, W, D, "right", 5.8, 2.2, 0.35, 1.9, 5, 0.8, key="car3", book_mats=("book_b", "book_c", "book_a"))
    wall_item(p, W, D, "right", 3.2, 0.6, 0.0, 0.45, 0.0, 1.2, "charge_box", collide=True)
    wall_item(p, W, D, "left", 5.0, 1.4, 0.0, 0.02, 1.2, 2.0, "cork")
    wall_item(p, W, D, "left", 5.0, 1.2, 0.02, 0.004, 1.3, 1.9, "paper")
    _light_curtains(ctx)


def study_4f(ctx):
    """4층: 개인 칸막이 16석 (가운데 세로 통로, 1.4m 가로 통로), 좌석 번호·스탠드·문제집, 감독석,
    모의고사 보관함, 휴대전화 보관함, 조용히 안내, 창 블라인드"""
    p, W, D = ctx.p, ctx.W, ctx.D
    _common(ctx, notice=False)
    wall_item(p, W, D, "front", W / 2 - 1.3, 0.6, 0.0, 0.02, 1.4, 1.8, "paper")
    wall_item(p, W, D, "front", W / 2 + 1.5, 0.7, 0.0, 0.3, 0.9, 1.5, "phone_box", collide=True)
    wall_item(p, W, D, "right", D * 0.5, 1.2, 0.0, 0.45, 0.0, 1.9, "cabinet_metal", collide=True)
    cu = W / 2
    for qu in (-1, 1):
        for qv in (0, 1):
            for r in range(2):
                v = (2.3, 3.5, 4.9, 6.1)[qv * 2 + r]
                for c in range(2):
                    u = cu + qu * (0.9 + c * 0.95)
                    carrel(p, u, v, facing=-1, w=0.85, lamp=True,
                           items=("number", "books") if (c + r) % 2 == 0 else ("number",), key="c4%d%d%d%d" % (qu, qv, r, c))
    blinds(ctx, "back", drop=0.6)


def _light_curtains(ctx):
    p, W, D = ctx.p, ctx.W, ctx.D
    wins = ctx.windows_on("back")
    if wins:
        for a in (wins[0].a0 - 0.28, wins[-1].a1 + 0.28):
            if 0.3 < a < W - 0.3:
                for i in range(3):
                    wall_item(p, W, D, "back", a + (i - 1) * 0.14, 0.16, 0.09 + 0.03 * (i % 2), 0.05, 0.7, 2.55, "curtain_light")


CLUBS = {("2F", "일반 동아리실 1"): "art", ("2F", "일반 동아리실 2"): "board", ("3F", "일반 동아리실 1"): "photo",
         ("3F", "일반 동아리실 2"): "science", ("4F", "일반 동아리실 1"): "news", ("4F", "일반 동아리실 2"): "service"}
CLUB_NAMES = {"art": "미술·공예부", "board": "문예·보드게임부", "photo": "사진·영상부", "science": "과학탐구부",
              "news": "신문·문예부", "service": "봉사·행사부"}


def club(ctx, kind):
    """일반 동아리실 6종 (앞 = 복도 문 벽, 뒤 = 북쪽 외벽 창)"""
    p, W, D = ctx.p, ctx.W, ctx.D
    if kind == "art":
        # 미술·공예: 작업대, 재료 선반, 건조 중인 작품, 재단 매트, 이젤, 세척 싱크
        p.box("workbench", W * 0.45, D * 0.55, 2.4, 1.1, 0.0, 0.8, collide=True)
        p.box("cutting_mat", W * 0.45 - 0.4, D * 0.55, 0.9, 0.6, 0.8, 0.81)
        for i in range(4):
            p.box("chair_seat", W * 0.45 - 0.9 + 0.6 * i, D * 0.55 + 0.85 * (1 if i % 2 else -1), 0.35, 0.35, 0.0, 0.62)
        shelf_along(p, W, D, "left", D * 0.5, 2.2, 0.4, 1.8, 4, 0.8, key="art", book_mats=("art_red", "art_blue", "box", "art_yellow"))
        wall_item(p, W, D, "right", D * 0.45, 1.2, 0.0, 0.4, 0.0, 1.6, "drying_rack", collide=True)
        for i in range(5):
            wall_item(p, W, D, "right", D * 0.45, 1.1, 0.02, 0.36, 0.3 + 0.28 * i, 0.31 + 0.28 * i, ("art_yellow", "paper", "art_red")[i % 3])
        for i, u in enumerate((W * 0.72, W * 0.86)):
            p.box("easel", u, D - 1.1, 0.06, 0.5, 0.0, 1.6, yaw=10.0 * (i - 0.5))
            p.box("canvas", u, D - 1.15, 0.6, 0.03, 0.9, 1.5, yaw=10.0 * (i - 0.5))
        wall_item(p, W, D, "back", 0.8, 0.8, 0.0, 0.55, 0.0, 0.85, "counter_white", collide=True)
        wall_item(p, W, D, "back", 0.8, 0.5, 0.05, 0.4, 0.85, 0.9, "porcelain")
    elif kind == "board":
        # 문예·보드게임: 큰 테이블, 보드게임 상자, 원고 묶음, 작은 책장, 프린터
        table(p, W * 0.45, D * 0.55, 2.4, 1.1, 3, along="u", key="bd")
        for i in range(3):
            p.box(("art_red", "art_blue", "art_green")[i], W * 0.45 - 0.6 + 0.5 * i, D * 0.55, 0.3, 0.3, 0.75, 0.82)
        p.box("paper", W * 0.45 + 0.8, D * 0.55, 0.3, 0.21, 0.75, 0.8)
        shelf_along(p, W, D, "left", D * 0.55, 2.2, 0.4, 1.8, 4, 0.9, key="bgs", book_mats=("art_red", "art_blue", "art_yellow", "art_green", "box"))
        shelf_along(p, W, D, "back", W * 0.78, 1.0, 0.3, 1.0, 2, 0.85, key="bgb")
        wall_item(p, W, D, "right", D * 0.4, 0.6, 0.0, 0.5, 0.0, 0.9, "copier", collide=True)
    elif kind == "photo":
        # 사진·영상: 카메라 보관장, 삼각대, 편집용 PC, 사진 게시판, 배경천, 조명
        wall_item(p, W, D, "left", D * 0.5, 1.2, 0.0, 0.45, 0.0, 1.8, "glass_case", collide=True)
        for i in range(4):
            wall_item(p, W, D, "left", D * 0.5 - 0.4 + 0.27 * i, 0.15, 0.15, 0.12, 0.9 + 0.4 * (i % 2), 1.02 + 0.4 * (i % 2), "camera")
        for i in range(2):
            p.box("metal_dark", W * 0.4 + 0.5 * i, D * 0.45, 0.04, 0.04, 0.0, 1.4, yaw=10.0)
        office_desk(p, W - 1.2, D * 0.5, facing=1, w=1.6, items=("monitor", "papers"), key="ph")
        wall_item(p, W, D, "front", W * 0.35, 1.6, 0.0, 0.02, 1.1, 1.9, "cork")
        for i in range(5):
            wall_item(p, W, D, "front", W * 0.35 - 0.6 + 0.3 * i, 0.2, 0.02, 0.004, 1.3 + 0.2 * (i % 2), 1.45 + 0.2 * (i % 2), "photo")
        wall_item(p, W, D, "back", W * 0.35, 2.0, 0.25, 0.02, 0.2, 2.4, "backdrop")
        for u in (W * 0.2, W * 0.55):
            p.box("metal_dark", u, D - 1.3, 0.04, 0.04, 0.0, 1.9)
            p.box("studio_light", u, D - 1.3, 0.35, 0.25, 1.9, 2.2)
    elif kind == "science":
        # 과학탐구: 작업대, 모형, 관찰 기록, 잠금 수납장, 현미경, 표본장
        p.box("lab_bench", W * 0.45, D * 0.55, 2.2, 1.0, 0.0, 0.88, collide=True)
        p.box("microscope", W * 0.45 - 0.5, D * 0.55, 0.2, 0.25, 0.88, 1.25)
        p.box("paper", W * 0.45 + 0.4, D * 0.55, 0.3, 0.21, 0.88, 0.89)
        p.box("globe", W * 0.45 + 0.8, D * 0.55 - 0.2, 0.3, 0.3, 0.88, 1.2)
        wall_item(p, W, D, "left", D * 0.5, 1.2, 0.0, 0.45, 0.0, 1.9, "glass_case", collide=True)
        for i in range(6):
            wall_item(p, W, D, "left", D * 0.5 - 0.45 + 0.18 * i, 0.12, 0.15, 0.12, 0.9 + 0.45 * (i % 2), 1.05 + 0.45 * (i % 2), "jar")
        cabinet(p, W - 0.6, D * 0.35, 0.9, 0.5, 1.8, "cabinet_metal", 2)
        p.box("steel", W - 0.6, D * 0.35 - 0.26, 0.08, 0.02, 1.0, 1.1)
        p.box("box", W - 0.6, D * 0.7, 0.5, 0.4, 0.0, 0.3)
    elif kind == "news":
        # 신문·문예: 편집 책상 + 컴퓨터, 프린터, 교지 묶음, 교정 중인 원고, 기사 배치판
        office_desk(p, 1.2, D * 0.5, facing=-1, w=1.4, items=("monitor", "papers"), key="nw1")
        office_desk(p, W - 1.3, D * 0.5, facing=-1, w=1.4, items=("monitor", "exam"), key="nw2")
        wall_item(p, W, D, "front", W * 0.5, 1.8, 0.0, 0.02, 1.0, 2.0, "cork")
        for i in range(8):
            wall_item(p, W, D, "front", W * 0.5 - 0.75 + 0.21 * i, 0.19, 0.02, 0.004, 1.15 + 0.35 * (i % 2), 1.42 + 0.35 * (i % 2), "paper")
        shelf_along(p, W, D, "back", W * 0.5, 2.0, 0.35, 1.2, 3, 0.95, key="nws", book_mats=("paper", "book_c", "paper_yellow"))
        wall_item(p, W, D, "right", D * 0.2 + 0.5, 0.6, 0.0, 0.5, 0.0, 0.9, "copier", collide=True)
    else:
        # 봉사·행사: 접이식 책상, 행사 상자, 봉사 조끼, 피켓, 구급함, 현수막, 활동 일정표
        table(p, W * 0.45, D * 0.5, 1.8, 0.7, 2, along="u", key="sv")
        for i in range(5):
            p.box("box", 0.5 + 0.45 * (i % 3), D - 0.6 - 0.45 * (i // 3), 0.42, 0.36, 0.36 * (i // 3 == 0 and i % 2), 0.36 + 0.36 * (i // 3 == 0 and i % 2))
        for i in range(4):
            wall_item(p, W, D, "right", D * 0.35 + 0.35 * i, 0.3, 0.02, 0.05, 1.1, 1.7, "vest")
        p.box("picket", W - 0.5, D - 0.4, 0.5, 0.03, 0.8, 1.2)
        p.box("metal_dark", W - 0.5, D - 0.4, 0.03, 0.03, 0.0, 0.8)
        wall_item(p, W, D, "front", W * 0.3, 0.35, 0.0, 0.14, 1.3, 1.6, "first_aid")
        p.box("banner_roll", W * 0.5, D - 0.35, 1.6, 0.14, 0.0, 0.14)
        wall_item(p, W, D, "left", D * 0.45, 1.2, 0.0, 0.02, 1.1, 1.9, "whiteboard")
