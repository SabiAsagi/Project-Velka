# -*- coding: utf-8 -*-
"""일반 교실 표준 배치 (가이드라인 3장) + 반별 소품.
앞(v=0) = 칠판 벽, 왼쪽(u=0) = 창가, 오른쪽(u=W) = 복도(앞문·뒷문), 뒤(v=D) = 사물함·게시판 벽."""
from props_base import (student_desk, chair, cabinet, shelf_unit, wall_board, plant, bins, curtain, label, facing_rows,
                        desk_item)

ROWS, COLS = 5, 6
ROW0, ROW_PITCH = 2.3, 0.9


def front_wall(ctx, board_text="", erased=False, dday=""):
    p, W, D = ctx.p, ctx.W, ctx.D
    bw = min(5.0, W - 3.2)
    bu = W / 2 - 0.25
    # 긴 녹색 칠판 + 알루미늄 테두리 + 분필받이·지우개
    p.box("frame_alu", bu, 0.02, bw + 0.08, 0.04, 0.81, 2.09)
    p.box("chalkboard_erased" if erased else "chalkboard", bu, 0.045, bw, 0.012, 0.85, 2.05)
    p.box("frame_alu", bu, 0.09, bw, 0.1, 0.8, 0.83)
    for i, du in enumerate((-bw * 0.3, bw * 0.1, bw * 0.35)):
        p.box("eraser", bu + du, 0.09, 0.14, 0.05, 0.83, 0.87)
    p.box("chalk", bu - bw * 0.15, 0.09, 0.1, 0.03, 0.83, 0.845)
    # 시계와 스피커 (칠판 위), 날짜·당번 메모 칠판
    p.box("clock_rim", bu, 0.03, 0.34, 0.05, 2.35, 2.69)
    p.box("clock_face", bu, 0.058, 0.28, 0.01, 2.38, 2.66)
    p.box("speaker", W - 0.75, 0.08, 0.4, 0.16, 2.72, 3.0)
    p.box("frame_wood", bu - 1.15, 0.02, 0.62, 0.04, 2.28, 2.72)                 # 태극기 액자
    p.box("flag_kr", bu - 1.15, 0.043, 0.54, 0.008, 2.32, 2.68)
    p.box("art_red", bu - 1.15, 0.049, 0.14, 0.004, 2.5, 2.57)
    p.box("art_blue", bu - 1.15, 0.049, 0.14, 0.004, 2.43, 2.5)
    p.box("frame_wood", bu + 1.35, 0.02, 1.2, 0.04, 2.32, 2.68)                  # 교훈 액자
    p.box("paper", bu + 1.35, 0.043, 1.12, 0.008, 2.35, 2.65)
    mu = bu + bw / 2 + 0.55
    if mu + 0.3 < W - 1.0:
        p.box("frame_alu", mu, 0.02, 0.64, 0.04, 1.06, 1.84)
        p.box("whiteboard", mu, 0.043, 0.6, 0.01, 1.08, 1.82)
    # 교실 앞 오른쪽 위 TV
    p.box("tv", 0.95, 0.12, 1.1, 0.08, 2.15, 2.8)
    sw, fr = ctx.sw, ctx.frame
    rows = facing_rows(fr, "back")
    if board_text:
        x, z = fr.pt(bu - bw * 0.25, 0.06)
        label(sw, ctx.container, (x, ctx.y + 1.55, z), board_text, 0.0045, 44, (0.93, 0.93, 0.88), rows, list(ctx.groups) or None)
    if mu + 0.3 < W - 1.0:
        x, z = fr.pt(mu, 0.052)
        label(sw, ctx.container, (x, ctx.y + 1.45, z), "날짜\n주번\n준비물", 0.0026, 32, (0.2, 0.25, 0.4), rows,
              list(ctx.groups) or None)
    x, z = fr.pt(bu + 1.35, 0.055)
    label(sw, ctx.container, (x, ctx.y + 2.5, z), "성실 · 배려 · 도전", 0.0028, 36, (0.15, 0.15, 0.2), rows, list(ctx.groups) or None)
    # 시간표 (칠판 왼쪽 = 창가 쪽, TV 아래)
    p.box("frame_alu", 0.95, 0.02, 0.74, 0.04, 1.02, 1.98)
    p.box("paper", 0.95, 0.043, 0.7, 0.008, 1.04, 1.96)
    for k in range(6):
        p.box("paper_blue" if k % 2 else "paper_yellow", 0.95, 0.049, 0.62, 0.004, 1.1 + 0.14 * k, 1.2 + 0.14 * k)
    x, z = fr.pt(0.95, 0.056)
    label(sw, ctx.container, (x, ctx.y + 1.9, z), "시간표", 0.0026, 32, (0.15, 0.15, 0.2), rows, list(ctx.groups) or None)
    if dday:
        x, z = fr.pt(bu + bw * 0.3, 0.06)
        label(sw, ctx.container, (x, ctx.y + 1.75, z), dday, 0.006, 56, (0.95, 0.85, 0.5), rows, list(ctx.groups) or None)
    return bu, bw


def teacher_zone(ctx, bu, bw):
    p = ctx.p
    # 교탁: 칠판에서 떨어뜨려 교사가 뒤에 서고 지나갈 수 있게
    tv = 1.25
    p.box("lectern", bu, tv, 0.95, 0.52, 0.0, 1.0, collide=True)
    p.box("lectern_top", bu, tv, 1.0, 0.56, 1.0, 1.04)
    p.box("attendance", bu - 0.2, tv - 0.02, 0.3, 0.22, 1.04, 1.06)
    p.box("chalk_box", bu + 0.18, tv + 0.05, 0.15, 0.1, 1.04, 1.1)
    p.box("pen_cup", bu + 0.36, tv - 0.08, 0.08, 0.08, 1.04, 1.16)
    # 교사용 작은 책상 (창가 쪽 앞) + 모니터
    tu = max(1.0, bu - bw / 2 - 0.1)
    p.box("desk_top", tu, 1.05, 1.1, 0.6, 0.71, 0.74)
    p.box("desk_frame", tu, 1.05, 1.02, 0.52, 0.0, 0.71, collide=True)
    p.box("monitor", tu, 1.15, 0.5, 0.05, 0.8, 1.12)
    p.box("metal_dark", tu, 1.18, 0.1, 0.1, 0.74, 0.8)
    return tv


def desk_cols(W):
    """책상 열 중심 (창가 -> 복도). 열 사이 0.85m 통로, 창가 0.9m, 복도 쪽은 문 앞 여유"""
    pitch = min(1.45, (W - 1.2 - 1.66) / (COLS - 1))
    return [1.2 + pitch * i for i in range(COLS)]


def desks(ctx, variant, W, D):
    p = ctx.p
    cols = desk_cols(W)
    items_pool = [("bag",), ("book",), ("pencil",), ("bottle",), ("books", "pencil"), (), (), (), ("book", "bottle"), ()]
    extra = variant.get("items", ())
    count = 0
    for r in range(ROWS):
        v = ROW0 + r * ROW_PITCH
        for c, u in enumerate(cols):
            if not p.free(u - 0.3, v - 0.25, u + 0.3, v + 0.65):
                continue
            yaw = 0.0
            if variant.get("crooked") and p.rand("crook", r, c) > 0.75:
                yaw = (p.rand("yaw", r, c) - 0.5) * 22.0
            items = list(items_pool[int(p.rand("it", r, c) * len(items_pool)) % len(items_pool)])
            if extra and p.rand("ex", r, c) > 0.45:
                items += list(extra)
            student_desk(p, u, v, items, yaw=yaw)
            pull = 0.12 if p.rand("pull", r, c) > 0.8 else 0.0
            cyaw = (p.rand("cy", r, c) - 0.5) * 30.0 if p.rand("ang", r, c) > 0.85 else yaw
            chair(p, u, v + 0.42 + pull, yaw=cyaw)
            if "cushion" in variant.get("chair_items", ()) and p.rand("cu", r, c) > 0.4:
                desk_item(p, u, v, "cushion")
            count += 1
    return count


def back_wall(ctx, variant, W, D):
    p = ctx.p
    # 뒤쪽 창가 모서리: 청소도구함 + 옆 분리수거함 (창 아래는 낮은 물건만)
    cabinet(p, 0.5, D - 0.3, 0.8, 0.55, 1.85, "cleaning_cabinet", doors=2, front=-1)
    bins(p, 0.26, D - 1.35, 3, along_u=False)
    if variant.get("extra") == "extra_desk":
        # 막힌 옛 문 모양: 색이 조금 다른 문 크기의 덧칠 자국과 문틀 흔적
        p.box("wall_patch", 1.45, D - 0.006, 0.95, 0.012, 0.0, 2.05)
        for du in (-0.5, 0.5):
            p.box("frame_alu", 1.45 + du, D - 0.012, 0.04, 0.024, 0.0, 2.1)
        p.box("frame_alu", 1.45, D - 0.012, 1.04, 0.024, 2.06, 2.1)
    else:
        # 학급문고 낮은 책장
        shelf_unit(p, 1.45, D - 0.17, 0.9, 0.3, 0.9, 2, 0.8, key="lib", front=-1)
    # 개인 사물함 (뒷문 쪽은 비운다)
    lu0, lu1 = 2.0, W - 1.6
    n = max(1, int((lu1 - lu0) / 0.4))
    lu1 = lu0 + n * 0.4
    messy = variant.get("messy_lockers")
    p.box("locker", (lu0 + lu1) / 2, D - 0.225, lu1 - lu0, 0.45, 0.0, 1.35, collide=True)
    for i in range(n + 1):
        p.box("locker_line", lu0 + i * 0.4, D - 0.452, 0.012, 0.006, 0.02, 1.33)
    for t in (0.45, 0.9):
        p.box("locker_line", (lu0 + lu1) / 2, D - 0.452, lu1 - lu0, 0.006, t - 0.006, t + 0.006)
    for i in range(n):
        for t in range(3):
            hu = lu0 + i * 0.4 + 0.3
            p.box("metal_dark", hu, D - 0.456, 0.05, 0.01, t * 0.45 + 0.2, t * 0.45 + 0.26)
            if messy and p.rand("open", i, t) > 0.82:
                p.box("locker", lu0 + i * 0.4 + 0.2, D - 0.62, 0.38, 0.02, t * 0.45 + 0.03, t * 0.45 + 0.42, yaw=35.0)
    # 사물함 위 체육복 가방·상자
    for i in range(n):
        r = p.rand("top", i)
        if r > 0.55:
            p.box("bag" if r > 0.8 else "box", lu0 + i * 0.4 + 0.2, D - 0.22, 0.32, 0.3, 1.35, 1.35 + 0.12 + 0.18 * r)
    # 학급 게시판 (사물함 위)
    wall_board(p, (lu0 + lu1) / 2, D, lu1 - lu0 - 0.2, 1.55, 2.5, -1, papers=variant.get("papers", 6), key="bb",
               paper_mats=variant.get("paper_mats", ("paper", "paper_yellow", "paper_blue", "paper_pink")))
    p.box("flashlight", lu1 + 0.25, D - 0.06, 0.08, 0.1, 1.2, 1.45)                 # 비상 손전등 (거치대)
    p.box("metal_dark", lu1 + 0.25, D - 0.02, 0.14, 0.04, 1.15, 1.5)
    av = 3.0
    if p.free(W - 0.3, av - 0.3, W, av + 0.3):                                    # 출석부 보관함 (복도 벽, 앞문 옆)
        p.box("cabinet_wood", W - 0.07, av, 0.14, 0.42, 1.15, 1.5)
        p.box("attendance", W - 0.15, av, 0.02, 0.3, 1.2, 1.45)
    # 벽 위쪽 설비: 냉난방기, 감지기
    p.box("aircon", W - 2.6, D - 0.14, 1.0, 0.26, 2.72, 3.08)
    p.box("sensor", W / 2, D - 0.05, 0.12, 0.08, 3.15, 3.25)
    return lu0, lu1


def window_side(ctx, variant):
    p, W, D = ctx.p, ctx.W, ctx.D
    wins = ctx.windows_on("left")
    if not wins:
        return
    first, last = wins[0], wins[-1]
    # 창 양끝 커튼 (창 기둥 쪽에 모아 둠)
    for a in (first.a0 - 0.3, last.a1 + 0.3):
        if 0.3 < a < D - 0.3:
            for i in range(3):
                p.box("curtain", 0.09 + 0.03 * (i % 2), a + (i - 1) * 0.15, 0.05, 0.17, 0.7, 2.55)
            p.box("frame_alu", 0.1, a, 0.03, 0.55, 2.56, 2.6)
    # 창 아래 난방기(방열기)와 교과서 상자
    for i, w in enumerate(wins[:2]):
        a = (w.a0 + w.a1) / 2
        if p.free(0.0, a - 0.6, 0.5, a + 0.6):
            p.box("aircon", 0.2, a, 0.14, 1.1, 0.12, 0.68)
            for k in range(7):
                p.box("metal_dark", 0.275, a - 0.45 + 0.15 * k, 0.006, 0.02, 0.16, 0.64)
    for k in range(2):                       # 교과서 상자 (칠판 쪽 창가 구석)
        p.box("box", 0.34, 0.42 + 0.02 * k, 0.5 - 0.04 * k, 0.4, 0.3 * k, 0.3 * (k + 1))
    # 창턱 화분 (몇 개만)
    plants = variant.get("plants", 2)
    placed = 0
    for i, w in enumerate(wins):
        for k in range(2):
            if placed >= plants:
                break
            if p.rand("pl", i, k) > 0.5 or plants > 3:
                a = w.a0 + 0.3 + (w.a1 - w.a0 - 0.6) * p.rand("plv", i, k)
                plant(p, 0.09, a, 0.915, 0.14)
                placed += 1


VARIANTS = {
    "1-1": {"plants": 8, "extra": "watering", "title": "우리 반 식물 관찰"},
    "1-2": {"papers": 14, "paper_mats": ("art_red", "art_blue", "art_yellow", "art_green", "paper"), "extra": "color_paper",
            "title": "미술 작품 전시"},
    "1-3": {"extra": "ball_basket", "title": "체육대회 준비"},
    "1-4": {"extra": "class_library", "title": "학급문고 대출 안내"},
    "1-5": {"extra": "decorations", "title": "학급 행사"},
    "1-6": {"messy_lockers": True, "crooked": True, "title": "1-6 게시판"},
    "2-1": {"extra": "festival", "papers": 10, "paper_mats": ("art_red", "art_yellow", "paper"), "title": "축제 준비"},
    "2-2": {"extra": "cheering", "title": "2-2 화이팅!"},
    "2-3": {"items": ("papers",), "title": "수행평가 일정", "papers": 9},
    "2-4": {"items": ("papers",), "title": "진로 탐색", "papers": 10, "paper_mats": ("paper_blue", "paper", "paper_yellow")},
    "2-5": {"items": ("pencil2", "bag"), "chair_items": ("cushion",), "title": "2-5 게시판"},
    "2-6": {"extra": "extra_desk", "title": "2-6 게시판"},
    "3-1": {"title": "수시 원서 접수 일정", "papers": 12},
    "3-2": {"extra": "mock_exam", "items": ("papers",), "title": "모의고사 대비"},
    "3-3": {"title": "진학 상담 일정", "papers": 8},
    "3-4": {"items": ("brochure",), "extra": "brochures", "title": "대학 안내"},
    "3-5": {"items": ("workbooks",), "title": "3-5 게시판"},
    "3-6": {"dday": "D-45", "erased": True, "title": "수능 D-45"},
    "2-7": {"extra": "extra_desk", "date": "6월 31일 (화)", "title": "2-7 게시판"},
}
DATE = "6월 3일 (화)"


def classroom(ctx, class_name):
    v = VARIANTS.get(class_name, {})
    W, D = ctx.W, ctx.D
    date = v.get("date", DATE)
    bu, bw = front_wall(ctx, date, v.get("erased", False), v.get("dday", ""))
    teacher_zone(ctx, bu, bw)
    n = desks(ctx, v, W, D)
    lu0, lu1 = back_wall(ctx, v, W, D)
    window_side(ctx, v)
    ctx.anchor("blackboard", bu - bw * 0.2, 0.05, bu - bw * 0.2, 0.62)
    ctx.anchor("chalk_name", bu + bw * 0.3, 0.05, bu + bw * 0.3, 0.62)
    ctx.anchor("attendance", bu - 0.2, 1.23, bu - 0.2, 2.0)
    ctx.anchor("locker", (lu0 + lu1) / 2, D - 0.45, (lu0 + lu1) / 2, D - 1.1)
    wins = ctx.windows_on("left")
    if wins:
        wv = (wins[len(wins) // 2].a0 + wins[len(wins) // 2].a1) / 2
        ctx.anchor("window", 0.05, wv, 0.8, wv)
    if class_name == "2-1":                  # 이계에서만 보이는 떨어진 필통 (책상 사이 통로 바닥)
        cols = desk_cols(W)
        pu, pv = (cols[len(cols) // 2 - 1] + cols[len(cols) // 2]) / 2, ROW0 + ROW_PITCH * (ROWS - 2) + 0.2
        ctx.p.box("pencil_case", pu, pv, 0.2, 0.07, 0.0, 0.04, yaw=25.0, groups=("otherworld_only",))
        ctx.anchor("pencilcase", pu, pv, pu, pv + 0.45)
    title = v.get("title", "")
    if title:
        x, z = ctx.frame.pt((lu0 + lu1) / 2, D - 0.045)
        label(ctx.sw, ctx.container, (x, ctx.y + 2.4, z), title, 0.0035, 40, (0.25, 0.15, 0.1), facing_rows(ctx.frame, "front"),
              list(ctx.groups) or None)
    extra = v.get("extra")
    p = ctx.p
    if extra == "watering":
        p.box("watering_can", 0.35, D - 2.2, 0.28, 0.16, 0.0, 0.26)
        p.box("watering_can", 0.45, D - 2.2, 0.08, 0.05, 0.18, 0.24)
    elif extra == "color_paper":
        for i, m in enumerate(("art_red", "art_yellow", "art_blue", "art_green")):
            p.box(m, 1.3 + 0.02 * i, D - 0.18, 0.3, 0.22, 0.9 + i * 0.012, 0.912 + i * 0.012)
    elif extra == "ball_basket":
        bu_, bv_ = 1.0, D - 1.25
        for du, dv in ((-0.3, 0), (0.3, 0), (0, -0.3), (0, 0.3)):
            p.box("metal_dark", bu_ + du, bv_ + dv, 0.62 if dv else 0.02, 0.02 if dv else 0.62, 0.05, 0.75)
        for i in range(6):
            p.box("ball", bu_ - 0.15 + 0.3 * (i % 2), bv_ - 0.15 + 0.15 * (i // 2), 0.22, 0.22, 0.52 + 0.05 * (i % 3), 0.74 + 0.05 * (i % 3))
        p.solid(bu_, bv_, 0.62, 0.62, 0.0, 0.75)
    elif extra == "class_library":
        from props_base import shelf_along
        shelf_along(p, W, D, "left", D - 2.3, 1.2, 0.3, 0.85, 2, 0.85, key="lib2")
        shelf_along(p, W, D, "left", D - 3.6, 1.2, 0.3, 0.85, 2, 0.85, key="lib3")
    elif extra == "decorations":
        for i in range(10):
            p.box("art_red" if i % 2 else "art_yellow", lu0 + 0.3 + i * (lu1 - lu0 - 0.6) / 9, D - 0.06, 0.2, 0.02,
                  2.52 - 0.06 * (i % 2), 2.6 - 0.06 * (i % 2))
        p.box("banner_roll", (lu0 + lu1) / 2, D - 0.62, 1.6, 0.14, 0.0, 0.14)
        p.box("box", lu0 + 0.4, D - 0.72, 0.4, 0.3, 0.0, 0.25)
    elif extra == "festival":
        p.box("sign_board", W - 2.5, D - 1.0, 1.8, 0.06, 0.0, 0.9, yaw=8.0)
        p.box("art_yellow", W - 2.5, D - 1.04, 1.4, 0.01, 0.2, 0.7, yaw=8.0)
    elif extra == "cheering":
        p.box("box", 1.4, D - 0.9, 0.45, 0.35, 0.0, 0.3)
        for i in range(5):
            p.box("cheer_stick", 1.25 + 0.07 * i, D - 0.9, 0.04, 0.04, 0.3, 0.75)
        p.box("frame_alu", W / 2, D - 0.04, 0.6, 0.02, 2.62, 3.02)
        p.box("photo", W / 2, D - 0.055, 0.54, 0.01, 2.65, 2.99)
    elif extra == "extra_desk":
        # 실제 인원보다 하나 많은 책상: 마지막 줄 뒤 가운데에 고정 (사물함 옆은 통행로로 쓰지 않는다)
        cols = desk_cols(W)
        eu = (cols[2] + cols[3]) / 2
        vv = ROW0 + ROWS * ROW_PITCH - 0.1
        student_desk(p, eu, vv, ())
        chair(p, eu, vv + 0.2)
        # 사용하지 않는 스피커 (뒷벽 위, 선이 늘어져 있다), 문 한 칸이 열린 빈 사물함
        p.box("speaker", W - 1.0, D - 0.09, 0.4, 0.16, 2.7, 2.98)
        p.box("metal_dark", W - 0.85, D - 0.02, 0.015, 0.015, 2.2, 2.7)
        eu2 = lu0 + 0.4 * 3
        p.box("metal_dark", eu2 + 0.2, D - 0.458, 0.36, 0.004, 0.94, 1.31)
        p.box("locker", eu2 + 0.02, D - 0.64, 0.02, 0.38, 0.92, 1.33)
    elif extra == "mock_exam":
        for i in range(3):
            p.box("file_box", lu0 + 0.3 + 0.45 * i, D - 0.22, 0.38, 0.3, 1.35, 1.62)
        for i in range(4):
            p.box("paper", bu + 0.25, 1.25, 0.3, 0.21, 1.04 + 0.03 * i, 1.065 + 0.03 * i)
    elif extra == "brochures":
        p.box("shelf_wood", W - 2.2, D - 0.9, 0.9, 0.3, 0.0, 1.2, collide=True)
        for i in range(6):
            p.box("paper_blue" if i % 2 else "paper_pink", W - 2.5 + 0.12 * i, D - 1.06, 0.1, 0.02, 0.5 + 0.1 * (i % 3), 0.85 + 0.1 * (i % 3))
    return n
