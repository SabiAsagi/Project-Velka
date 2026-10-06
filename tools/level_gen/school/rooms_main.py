# -*- coding: utf-8 -*-
"""본관 1층 업무 공간 (학교_맵_상세.md 1층 주요 공간 + 가이드라인 5장). 좌표: 문(복도) 쪽 벽 = 앞(v=0)."""
from props_base import wall_item, cabinet, shelf_unit, shelf_along, bench, plant, bins, label, facing_rows, wall_board
from props_more import office_desk, table, sofa, bed, blinds, curtains_full, whiteboard_wall


def lobby(ctx):
    """중앙 현관·로비 (앞 = 현관 유리문 벽): 매트, 우산꽂이, 방문객 기록대, 안내도, 졸업사진, 트로피 진열장(동),
    연혁·교훈(서), 대기 벤치 2개, AED, 휠체어, 분실물함. 현관에서 복도까지 2.5~3m 직선 동선은 비운다."""
    p, W, D = ctx.p, ctx.W, ctx.D
    doors = ctx.doors_on("front")
    dm = doors[0].mid if doors else W / 2
    p.box("mat_dark", dm, 1.0, 2.6, 1.6, 0.0, 0.012)
    for s in (-1, 1):
        u = dm + s * 1.75
        p.box("bin_gray", u, 0.45, 0.32, 0.32, 0.0, 0.6)
        for k in range(4):
            p.box("umbrella", u - 0.08 + 0.05 * k, 0.45, 0.035, 0.035, 0.3, 0.9 + 0.04 * k)
    # 서쪽(왼쪽) 벽: 연혁·교훈 액자와 학교 안내도, 방문객 기록대
    wside, eside = ("left", "right") if ctx.frame.world_side("left") == "x0" else ("right", "left")
    wall_item(p, W, D, wside, D * 0.35, 1.4, 0.0, 0.04, 1.3, 2.3, "frame_wood")
    wall_item(p, W, D, wside, D * 0.35, 1.3, 0.04, 0.01, 1.35, 2.25, "paper")
    wall_item(p, W, D, wside, D * 0.62, 1.8, 0.0, 0.03, 1.0, 2.1, "frame_alu")
    wall_item(p, W, D, wside, D * 0.62, 1.74, 0.03, 0.01, 1.03, 2.07, "floor_map")
    u_w = 0.35 if wside == "left" else W - 0.35
    p.box("office_top", u_w, D * 0.18, 0.6, 1.0, 0.95, 1.0, collide=True)
    p.box("office_panel", u_w, D * 0.18, 0.5, 0.9, 0.0, 0.95)
    p.box("paper", u_w, D * 0.18, 0.3, 0.4, 1.0, 1.01)
    # 동쪽(오른쪽) 벽: 트로피 진열장, 졸업사진, AED, 휠체어, 분실물함
    wall_item(p, W, D, eside, D * 0.42, 1.6, 0.0, 0.45, 0.0, 1.9, "glass_case", collide=True)
    for i in range(6):
        wall_item(p, W, D, eside, D * 0.42 - 0.6 + 0.24 * i, 0.12, 0.15, 0.12, 0.9 + 0.45 * (i % 2), 1.15 + 0.45 * (i % 2), "trophy")
    for i in range(4):
        wall_item(p, W, D, eside, D * 0.7 - 0.75 + 0.5 * i, 0.4, 0.0, 0.03, 1.5, 1.8, "photo")
    wall_item(p, W, D, eside, D * 0.18, 0.4, 0.0, 0.16, 1.1, 1.55, "aed")
    wall_item(p, W, D, eside, D * 0.86, 0.6, 0.02, 0.45, 0.0, 0.8, "lost_box", collide=True)
    wheel_u = W - 0.5 if eside == "right" else 0.5
    p.box("metal_dark", wheel_u, D * 0.27, 0.55, 0.6, 0.45, 0.5)
    p.box("metal_dark", wheel_u, D * 0.27 + 0.28, 0.5, 0.05, 0.5, 0.95)
    # 대기 벤치 2개 (양쪽 벽, 가운데 통로는 비움)
    for side in (wside, eside):
        u = 0.3 if side == "left" else W - 0.3
        bench(p, u, D * 0.55 if side == wside else D * 0.62, 1.4, along_u=False)


def admin(ctx):
    """행정실: 입구 가까이 민원 창구(카운터), 안쪽 직원 책상 4~6개, 서류장·금고·복합기·우편물함·직인함·출입통제 단말"""
    p, W, D = ctx.p, ctx.W, ctx.D
    doors = ctx.doors_on("front")
    dm = doors[0].mid if doors else W - 1.0
    gap0 = dm - 0.8
    # 민원 카운터: 문 앞 대기 공간 뒤로 가로질러, 문 쪽 끝은 직원 통로로 열어 둔다
    c0, c1 = (0.0, gap0) if dm > W / 2 else (dm + 0.8, W)
    p.box("counter_wood", (c0 + c1) / 2, 1.85, c1 - c0, 0.55, 0.0, 1.05, collide=True)
    p.box("counter_top", (c0 + c1) / 2, 1.85, c1 - c0 + 0.04, 0.62, 1.05, 1.09)
    p.box("seal_box", (c0 + c1) / 2 - 0.4, 1.8, 0.2, 0.14, 1.09, 1.15)
    p.box("paper", (c0 + c1) / 2 + 0.3, 1.75, 0.3, 0.21, 1.09, 1.1)
    for i, (u, v) in enumerate(((W * 0.3, 3.6), (W * 0.7, 3.6), (W * 0.3, 5.4), (W * 0.7, 5.4))):
        if p.free(u - 0.7, v - 1.0, u + 0.7, v + 0.5):
            office_desk(p, u, v, facing=-1, w=1.2, items=("monitor", "papers", "mug"), key="adm%d" % i)
    wall_item(p, W, D, "left", D * 0.62, 1.8, 0.0, 0.45, 0.0, 1.9, "cabinet_metal", collide=True)
    wall_item(p, W, D, "left", D * 0.8, 0.9, 0.0, 0.45, 0.0, 1.9, "cabinet_metal", collide=True)
    wall_item(p, W, D, "back", W * 0.2, 0.6, 0.0, 0.55, 0.0, 0.9, "safe", collide=True)
    wall_item(p, W, D, "right", D * 0.72, 0.7, 0.0, 0.6, 0.0, 1.15, "copier", collide=True)
    wall_item(p, W, D, "left", 2.6, 0.9, 0.0, 0.3, 1.0, 1.9, "mailbox")
    wall_item(p, W, D, "front", (c0 + c1) / 2, 0.15, 0.0, 0.08, 1.3, 1.55, "terminal")
    blinds(ctx, "back")


def staff_office(ctx):
    """교무실: 교사 책상 10개(4열 3줄, 셋째 줄 가운데는 회의 테이블, 가운데 1.2~1.5m 주통로), 부장 자리, 공용 책장, 인쇄기,
    머그컵·시험지 묶음·이름표, 열쇠 반납판, 창가 낮은 수납장"""
    p, W, D = ctx.p, ctx.W, ctx.D
    cols = [W * 0.17, W * 0.35, W * 0.65, W * 0.83]
    rows = [2.3, 3.9, 5.5]
    # 회의 테이블 (안쪽 끝). 교무실 깊이가 약 7.7m라 셋째 줄 가운데 두 책상 자리를 회의 테이블이 쓴다
    table(p, W * 0.5, D - 2.35, 3.2, 1.1, 4, along="u", key="meet")
    for r, v in enumerate(rows):
        for c, u in enumerate(cols):
            facing = 1 if r % 2 == 0 else -1
            if r == len(rows) - 1 and c in (1, 2):
                continue                                   # 회의 테이블 자리
            if p.free(u - 0.65, v - 0.8, u + 0.65, v + 0.8):
                office_desk(p, u, v, facing=facing, w=1.2, items=("monitor", "papers", "mug", "nameplate") + (("exam",) if (r + c) % 3 == 0 else ()),
                            key="st%d%d" % (r, c))
    # 부장 교사 자리 (앞쪽, 조금 큰 책상)
    office_desk(p, W * 0.5, 1.75, facing=1, w=1.6, items=("monitor", "papers", "mug", "nameplate"), key="head")
    # 창가 낮은 수납장, 공용 책장, 인쇄기, 열쇠 반납판, 커피 테이블
    wall_item(p, W, D, "back", W * 0.5, W - 2.0, 0.0, 0.45, 0.0, 0.85, "cabinet_wood", collide=True)
    shelf_along(p, W, D, "left", D * 0.45, 2.4, 0.35, 1.9, 5, 0.8, key="stb")
    wall_item(p, W, D, "right", D * 0.4, 0.75, 0.0, 0.6, 0.0, 1.15, "copier", collide=True)
    wall_item(p, W, D, "front", W * 0.5, 0.8, 0.0, 0.04, 1.2, 1.8, "key_board")
    for i in range(12):
        wall_item(p, W, D, "front", W * 0.5 - 0.3 + 0.12 * (i % 6), 0.02, 0.04, 0.02, 1.6 - 0.2 * (i // 6), 1.66 - 0.2 * (i // 6), "steel")
    wall_item(p, W, D, "right", D * 0.72, 1.0, 0.0, 0.5, 0.0, 0.9, "counter_white", collide=True)
    wall_item(p, W, D, "right", D * 0.72 - 0.25, 0.25, 0.1, 0.3, 0.9, 1.3, "coffee")
    wall_item(p, W, D, "right", D * 0.72 + 0.2, 0.2, 0.1, 0.25, 0.9, 1.35, "purifier")
    blinds(ctx, "back", drop=0.35)


def principal(ctx):
    """교장실: 남쪽 창가를 등진 책상, 응접 소파와 낮은 탁자, 책장·상패, 교기·태극기, 소형 금고"""
    p, W, D = ctx.p, ctx.W, ctx.D
    office_desk(p, W / 2, D - 1.55, facing=-1, w=1.6, d=0.8, items=("monitor", "papers", "nameplate"), key="pr")
    for s in (-1, 1):
        u = W / 2 + s * 1.15
        p.box("metal_dark", u, D - 0.45, 0.05, 0.05, 0.0, 2.2)
        p.box("flag_kr" if s < 0 else "flag_school", u + 0.25 * s, D - 0.45, 0.5, 0.02, 1.4, 2.1)
    sofa(p, 0.5, D * 0.42, 1.8, facing=1, along="v")
    sofa(p, W - 0.5, D * 0.42, 1.8, facing=-1, along="v")
    p.box("table_low", W / 2, D * 0.42, 0.8, 1.3, 0.0, 0.42, collide=True)
    p.box("cup_white", W / 2 - 0.1, D * 0.42, 0.08, 0.08, 0.42, 0.5)
    shelf_along(p, W, D, "left", D * 0.68, 1.6, 0.35, 1.9, 5, 0.6, key="prb", book_mats=("book_a", "trophy", "book_c", "frame_wood"))
    wall_item(p, W, D, "right", D * 0.68, 0.5, 0.0, 0.45, 0.0, 0.7, "safe", collide=True)
    blinds(ctx, "back", drop=0.3)


def nurse(ctx):
    """보건실: 출입문 옆 보건교사 책상·처치대, 남측 창가 침대 3개와 사이 커튼, 약품장, 세면대, 소형 냉장고,
    휠체어·접이식 들것. 침대 사이 0.9m, 안쪽 침대까지 1.2m 통로. 복도에서 침상이 바로 보이지 않게 커튼."""
    p, W, D = ctx.p, ctx.W, ctx.D
    doors = ctx.doors_on("front")
    d0 = doors[0].mid if doors else 1.5
    office_desk(p, d0 + 1.6, 2.2, facing=1, w=1.3, items=("monitor", "papers", "mug"), key="nd")
    p.box("counter_white", d0 + 3.4, 2.1, 1.4, 0.6, 0.0, 0.9, collide=True)
    p.box("steel", d0 + 3.2, 2.1, 0.3, 0.2, 0.9, 0.98)
    # 침대 구역 가림 커튼 (가운데를 비워 1.2m 통로)
    cv = D - 3.35
    beds_u = [W * 0.3, W * 0.3 + 1.9, W * 0.3 + 3.8]
    for u in beds_u:
        bed(p, u, D - 1.25, along="v")
    for u in beds_u[:-1]:
        p.box("cloth", u + 0.95, D - 1.25, 0.04, 2.0, 0.25, 2.1)
    p.box("frame_alu", (beds_u[0] + beds_u[-1]) / 2, cv, beds_u[-1] - beds_u[0] + 1.4, 0.04, 2.25, 2.3)
    for i, u in enumerate(beds_u):
        if i != 1:
            p.box("cloth", u, cv, 0.95, 0.05, 0.3, 2.2)
    wall_item(p, W, D, "right", D * 0.5, 1.4, 0.0, 0.45, 0.0, 1.9, "medicine_cabinet", collide=True)
    for i in range(6):
        wall_item(p, W, D, "right", D * 0.5 - 0.5 + 0.2 * i, 0.12, 0.4, 0.06, 1.1 + 0.35 * (i % 2), 1.25 + 0.35 * (i % 2), "bottle")
    wall_item(p, W, D, "left", 2.0, 0.7, 0.0, 0.5, 0.0, 0.85, "counter_white", collide=True)
    wall_item(p, W, D, "left", 2.0, 0.45, 0.05, 0.35, 0.85, 0.9, "porcelain")
    wall_item(p, W, D, "left", 2.0, 0.5, 0.0, 0.02, 1.2, 1.8, "mirror")
    wall_item(p, W, D, "left", 3.1, 0.55, 0.0, 0.55, 0.0, 0.85, "fridge_small", collide=True)
    wall_item(p, W, D, "left", 4.2, 0.25, 0.0, 1.9, 0.0, 0.2, "stretcher")
    p.box("metal_dark", 1.2, D * 0.55, 0.55, 0.6, 0.45, 0.5)
    p.box("metal_dark", 1.2, D * 0.55 + 0.28, 0.5, 0.05, 0.5, 0.95)
    from rooms_class import window_side
    curtains = ctx.windows_on("back")
    for w in curtains:
        for a in (w.a0 - 0.2, w.a1 + 0.2):
            wall_item(p, W, D, "back", a, 0.3, 0.09, 0.06, 0.7, 2.55, "curtain")
    ctx.anchor("cabinet", W - 0.45, D * 0.5, W - 1.25, D * 0.5)
    ctx.anchor("bed", beds_u[0], D - 1.25, beds_u[0], D - 2.75)


def broadcast(ctx):
    """방송실: 음향 콘솔·마이크·컴퓨터 2~3대, 작은 녹음 부스(관찰창), 장비 랙, 비상방송 패널, 카메라·케이블 상자.
    녹음 부스와 장비장 사이 1.2m, 외부창에는 두꺼운 커튼."""
    p, W, D = ctx.p, ctx.W, ctx.D
    # 콘솔 책상 (왼쪽 벽을 따라)
    wall_item(p, W, D, "left", D * 0.45, 2.6, 0.0, 0.8, 0.72, 0.76, "console")
    wall_item(p, W, D, "left", D * 0.45, 2.5, 0.05, 0.7, 0.0, 0.72, "office_panel", collide=True)
    for i in range(3):
        wall_item(p, W, D, "left", D * 0.45 - 0.8 + 0.8 * i, 0.5, 0.1, 0.05, 0.8, 1.12, "monitor")
    wall_item(p, W, D, "left", D * 0.45, 0.06, 0.45, 0.06, 0.76, 1.1, "metal_dark")
    for i in range(2):
        p.box("chair_office", 1.3, D * 0.45 - 0.5 + i, 0.46, 0.46, 0.44, 0.5)
    # 녹음 부스: 안쪽 오른쪽 모서리, 콘솔을 향한 관찰창
    bu0, bu1, bv0 = W - 2.8, W - 0.02, D - 2.6
    p.box("booth_wall", (bu0 + bu1) / 2, bv0, bu1 - bu0, 0.1, 0.0, 2.4, collide=True)
    p.box("booth_wall", bu0, (bv0 + D) / 2, 0.1, D - bv0, 0.0, 2.4, collide=True)
    p.box("glass_dark", (bu0 + bu1) / 2 - 0.3, bv0 - 0.06, 1.2, 0.02, 1.0, 1.8)
    p.box("chair_office", bu0 + 1.4, D - 1.2, 0.46, 0.46, 0.44, 0.5)
    p.box("metal_dark", bu0 + 1.4, D - 1.7, 0.05, 0.05, 0.9, 1.5)
    # 장비 랙 (오른쪽 벽 앞쪽, 부스와 1.2m 띄움)
    for i in range(2):
        wall_item(p, W, D, "right", 1.8 + 0.7 * i, 0.6, 0.0, 0.6, 0.0, 1.9, "rack", collide=True)
    wall_item(p, W, D, "front", W * 0.35, 0.5, 0.0, 0.08, 1.2, 1.7, "panel_red")
    p.box("box", W * 0.5, D - 0.5, 0.5, 0.4, 0.0, 0.35)
    p.box("cable_reel", W * 0.5 + 0.6, D - 0.45, 0.4, 0.4, 0.0, 0.3)
    curtains_full(ctx, "back")


def guard(ctx):
    """경비실: 복도 관찰창 아래 책상, CCTV 모니터, 열쇠함, 무전기 충전대, 출입 장부, 손전등, 비상벨, 휴식 의자"""
    p, W, D = ctx.p, ctx.W, ctx.D
    doors = ctx.doors_on("front")
    d0 = doors[0] if doors else None
    # 문 앞을 피해 복도 관찰창 아래에 책상
    if d0 is None or d0.mid > W / 2:
        a0, a1 = 0.12, (d0.a0 - 0.35) if d0 else W / 2
    else:
        a0, a1 = d0.a1 + 0.35, W - 0.12
    dw = max(0.9, min(2.0, a1 - a0))
    du = (a0 + a1) / 2
    dm = d0.mid if d0 else W - 1.0
    p.box("office_top", du, 0.45, dw, 0.7, 0.71, 0.74, collide=True)
    p.box("office_panel", du, 0.45, dw - 0.1, 0.6, 0.0, 0.71)
    for i in range(max(2, int(dw / 0.42))):
        p.box("monitor", du - dw / 2 + 0.25 + 0.42 * i, 0.2, 0.36, 0.04, 0.8, 1.05)
    p.box("attendance", du + 0.6, 0.55, 0.3, 0.22, 0.74, 0.76)
    p.box("flashlight", du - 0.8, 0.6, 0.05, 0.2, 0.74, 0.79)
    p.box("chair_office", du, 1.2, 0.46, 0.46, 0.44, 0.5)
    wall_item(p, W, D, "back", W * 0.3, 0.6, 0.0, 0.1, 1.2, 1.8, "key_board")
    wall_item(p, W, D, "back", W * 0.7, 0.4, 0.0, 0.25, 1.0, 1.3, "rack")
    wall_item(p, W, D, "right" if dm < W / 2 else "left", D * 0.6, 0.1, 0.0, 0.06, 1.3, 1.4, "panel_red")
    p.box("sofa", W / 2, D - 0.6, 0.7, 0.7, 0.0, 0.45, collide=True)
    p.box("sofa", W / 2, D - 0.3, 0.7, 0.15, 0.45, 0.85)


def council(ctx):
    """학생회실: 가운데 회의 테이블(8~12석), 회장단 책상, 화이트보드, 행사 일정표, 현수막·피켓·조끼·확성기, 옛 자료 선반.
    창가는 자료 상자로 일부 가리되 문 주변은 비운다."""
    p, W, D = ctx.p, ctx.W, ctx.D
    table(p, W * 0.45, D * 0.55, min(3.6, W - 3.0), 1.2, 5 if W > 8 else 4, along="u", key="cc")
    office_desk(p, W - 1.2, D - 1.0, facing=-1, w=1.4, items=("monitor", "papers"), key="cp")
    whiteboard_wall(p, W, D, "left", D * 0.55, 1.8)
    shelf_along(p, W, D, "back", W * 0.35, 2.2, 0.4, 1.8, 4, 0.7, key="cs", book_mats=("box", "file_box", "book_b", "paper"))
    for i in range(3):
        p.box("box", 0.5 + 0.55 * i, D - 0.9, 0.5, 0.4, 0.0, 0.35 + 0.1 * (i % 2))
    p.box("picket", W * 0.7, D - 0.25, 0.5, 0.03, 0.8, 1.2)
    p.box("metal_dark", W * 0.7, D - 0.25, 0.03, 0.03, 0.0, 0.8)
    p.box("vest", W * 0.82, D - 0.1, 0.4, 0.05, 1.2, 1.7)
    p.box("megaphone", W * 0.45 + 1.0, D * 0.55, 0.15, 0.3, 0.75, 0.9)


def entrance_passage(ctx):
    """본관 좌·우 출입구 통로: 매트, 우산꽂이, 신발장, 학교 안내판"""
    p, W, D = ctx.p, ctx.W, ctx.D
    doors = [d for d in ctx.doors if d.kind == "glass_entry"]
    if not doors:
        return
    d = doors[0]
    if d.side in ("front", "back"):
        v = 1.0 if d.side == "front" else D - 1.0
        p.box("mat_dark", d.mid, v, min(W - 0.4, 2.2), 1.4, 0.0, 0.012)
    wall_item(p, W, D, "left", D * 0.55, 1.4, 0.0, 0.4, 0.0, 1.2, "shoe_rack", collide=True)
    for i in range(4):
        wall_item(p, W, D, "left", D * 0.55 - 0.52 + 0.35 * i, 0.3, 0.4, 0.005, 0.1, 1.1, "locker_line")
    p.box("bin_gray", W - 0.3, 1.6, 0.3, 0.3, 0.0, 0.6)
    wall_item(p, W, D, "right", D * 0.5, 0.9, 0.0, 0.03, 1.2, 1.9, "floor_map")
