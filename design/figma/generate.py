"""Generates one 360x720 SVG per whiteboard screen (editable text/shapes).

Run: python design/figma/generate.py
Output: design/figma/NN_Name.svg  (paste into Figma, or import into Moqups)
"""
import os
from xml.sax.saxutils import escape

OR = "#F37021"      # primary orange
OR_SOFT = "#FFEDE0"
PEACH = "#FFE3CF"
TXT = "#1C1E21"
GRAY = "#65676B"
BORDER = "#CED0D4"
BG = "#F5F6F7"
GREEN = "#2E9E5B"
RED = "#D93025"
FONT = "Inter, Arial, sans-serif"
W, H = 360, 720


class S:
    def __init__(self):
        self.p = []

    def rect(self, x, y, w, h, fill="#fff", stroke=None, r=0, sw=1):
        st = f' stroke="{stroke}" stroke-width="{sw}"' if stroke else ""
        self.p.append(f'<rect x="{x}" y="{y}" width="{w}" height="{h}" rx="{r}" fill="{fill}"{st}/>')

    def text(self, x, y, s, size=14, weight=400, fill=TXT, anchor="start"):
        self.p.append(
            f'<text x="{x}" y="{y}" font-family="{FONT}" font-size="{size}" font-weight="{weight}" '
            f'fill="{fill}" text-anchor="{anchor}">{escape(s)}</text>')

    def line(self, x1, y1, x2, y2, c=BORDER):
        self.p.append(f'<line x1="{x1}" y1="{y1}" x2="{x2}" y2="{y2}" stroke="{c}"/>')

    def circle(self, cx, cy, r, fill):
        self.p.append(f'<circle cx="{cx}" cy="{cy}" r="{r}" fill="{fill}"/>')

    # ---- components
    def appbar(self, title, back=True):
        self.rect(0, 0, W, 56, OR)
        if back:
            self.text(20, 35, "←", 22, 600, "#fff")
        self.text(52 if back else 20, 35, title, 18, 600, "#fff")

    def field(self, x, y, w, label, value="", h=44):
        self.text(x, y - 8, label, 12, 600, TXT)
        self.rect(x, y, w, h, "#fff", BORDER, 10)
        if value:
            self.text(x + 14, y + h / 2 + 5, value, 14, 400, TXT)

    def button(self, x, y, w, label, fill=OR, fg="#fff", h=48, stroke=None):
        self.rect(x, y, w, h, fill, stroke, 10)
        self.text(x + w / 2, y + h / 2 + 5, label, 15, 600, fg, "middle")

    def chip(self, x, y, label, bg, fg, w=None):
        w = w or (len(label) * 7 + 20)
        self.rect(x, y, w, 22, bg, None, 11)
        self.text(x + w / 2, y + 15, label, 11, 600, fg, "middle")
        return w

    def card(self, x, y, w, h):
        self.rect(x, y, w, h, "#fff", BORDER, 12)

    def row(self, y, label, value):
        self.text(20, y, label, 13, 400, GRAY)
        self.text(340, y, value, 13, 600, TXT, "end")
        self.line(20, y + 12, 340, y + 12, "#E4E6EB")

    def build(self, name):
        body = "\n  ".join(self.p)
        return (f'<svg xmlns="http://www.w3.org/2000/svg" width="{W}" height="{H}" viewBox="0 0 {W} {H}">\n'
                f'  <rect width="{W}" height="{H}" fill="#fff"/>\n  {body}\n</svg>\n')


def screens():
    out = {}

    # 1 Login
    s = S()
    s.rect(0, 0, W, 300, PEACH)
    s.rect(0, 200, W, 100, "#FFF0E6")
    s.text(24, 70, "MyFSchool", 26, 800, OR)
    s.text(24, 130, "Chào mừng quý phụ huynh", 22, 700, TXT)
    s.field(24, 175, 312, "Tài khoản")
    s.text(24, 255, "Mật khẩu", 12, 600, TXT)
    s.text(336, 255, "Quên mật khẩu ?", 12, 600, OR, "end")
    s.rect(24, 262, 312, 44, "#fff", BORDER, 10)
    s.text(316, 289, "◉", 14, 400, GRAY, "end")
    s.rect(24, 322, 16, 16, OR, None, 3)
    s.text(28, 335, "✓", 12, 700, "#fff")
    s.text(48, 335, "Lưu thông tin đăng nhập", 13, 400, TXT)
    s.button(24, 360, 312, "Đăng nhập")
    s.line(24, 436, 120, 436)
    s.text(180, 440, "Hoặc đăng nhập bằng", 12, 400, GRAY, "middle")
    s.line(240, 436, 336, 436)
    s.button(24, 460, 312, "FEID", OR_SOFT, OR)
    s.text(180, 680, "Phiên bản 1.0.0", 11, 400, GRAY, "middle")
    s.text(180, 696, "Copyright MyFSchool", 11, 400, GRAY, "middle")
    out["01_Login"] = s

    # 2 Reset password
    s = S()
    s.appbar("Quên mật khẩu")
    s.text(24, 110, "Đặt lại mật khẩu", 22, 700, TXT)
    s.text(24, 134, "Nhập tài khoản và mật khẩu mới của bạn.", 13, 400, GRAY)
    s.field(24, 175, 312, "Tài khoản (email hoặc số điện thoại)")
    s.field(24, 250, 312, "Mật khẩu mới")
    s.field(24, 325, 312, "Nhập lại mật khẩu mới")
    s.button(24, 400, 312, "Đặt lại mật khẩu")
    s.text(180, 480, "Quay lại đăng nhập", 14, 600, OR, "middle")
    out["02_ResetPass"] = s

    # 3 Home
    s = S()
    s.appbar("MyFSchool", back=False)
    s.text(320, 35, "⎋", 20, 600, "#fff")
    s.card(16, 72, 328, 70)
    s.circle(52, 107, 22, OR_SOFT)
    s.text(52, 113, "NA", 14, 700, OR, "middle")
    s.text(86, 100, "Xin chào, Nguyễn Văn An", 15, 700, TXT)
    s.text(86, 120, "Vai trò: PH (Phụ huynh)", 12, 400, GRAY)
    x = 16
    for r in ("GV", "Manager", "PH", "HS"):
        w = len(r) * 8 + 24
        if r == "PH":
            s.chip(x, 158, r, OR, "#fff", w)
        else:
            s.chip(x, 158, r, "#EEE", GRAY, w)
        x += w + 8
    tiles = [("Thời khóa biểu", "▦"), ("Bảng điểm", "★"), ("Đơn từ", "✎"), ("Câu lạc bộ", "☺")]
    for i, (t, ic) in enumerate(tiles):
        tx = 16 + (i % 2) * 168
        ty = 200 + (i // 2) * 168
        s.card(tx, ty, 160, 152)
        s.text(tx + 80, ty + 76, ic, 40, 400, OR, "middle")
        s.text(tx + 80, ty + 122, t, 14, 600, TXT, "middle")
    s.text(180, 560, "Các ô hiển thị theo vai trò (GV, Manager, PH, HS)", 11, 400, GRAY, "middle")
    out["03_HomePage"] = s

    # 4 List schedule
    s = S()
    s.appbar("Thời khóa biểu")
    s.text(180, 90, "Tuần 7: 14/10 - 19/10/2026", 14, 600, TXT, "middle")
    s.text(24, 90, "‹", 20, 400, GRAY)
    s.text(336, 90, "›", 20, 400, GRAY, "end")
    days = ["T2", "T3", "T4", "T5", "T6", "T7"]
    s.rect(16, 108, 328, 28, OR_SOFT, None, 6)
    s.text(36, 127, "Tiết", 11, 600, OR, "middle")
    for i, d in enumerate(days):
        s.text(86 + i * 48, 127, d, 11, 600, OR, "middle")
    subj = [["Toán", "Văn", "Anh", "Toán", "Lý", "Văn"], ["Anh", "Toán", "Văn", "Hóa", "Sinh", "Anh"],
            ["Lý", "Sinh", "Sử", "Văn", "Hóa", "GDCD"], ["Địa", "Hóa", "Anh", "Tin", "Sử", "SHL"],
            ["Thể dục", "Tin", "Địa", "Sinh", "Thể dục", ""]]
    for r, row in enumerate(subj):
        y = 142 + r * 46
        s.text(36, y + 27, str(r + 1), 11, 600, GRAY, "middle")
        for c, name in enumerate(row):
            if name:
                s.rect(64 + c * 48, y, 44, 40, "#fff", BORDER, 6)
                s.text(86 + c * 48, y + 24, name, 10, 600, TXT, "middle")
    s.card(16, 392, 328, 90)
    s.text(30, 418, "Hôm nay - Thứ Tư", 14, 700, TXT)
    s.text(30, 442, "Tiết 1: Anh - P.305 - Cô Lan", 12, 400, GRAY)
    s.text(30, 462, "Tiết 2: Văn - P.201 - Cô Hoa", 12, 400, GRAY)
    s.text(180, 510, "Chạm vào ô tiết học để xem chi tiết", 11, 400, GRAY, "middle")
    out["04_ListSchedule"] = s

    # 5 List grade
    s = S()
    s.appbar("Bảng điểm")
    s.rect(16, 72, 328, 96, OR, None, 12)
    s.text(32, 98, "Điểm trung bình học kỳ 1", 12, 400, "#fff")
    s.text(32, 140, "8.42", 38, 800, "#fff")
    s.text(328, 126, "Xếp loại: Giỏi", 12, 600, "#fff", "end")
    s.text(328, 146, "Hạnh kiểm: Tốt", 12, 600, "#fff", "end")
    s.rect(16, 184, 328, 30, OR_SOFT, None, 6)
    for x, h_ in ((28, "Môn học"), (230, "Giữa kỳ"), (284, "Cuối kỳ"), (330, "TB")):
        s.text(x, 204, h_, 11, 700, OR, "start" if x == 28 else "middle")
    rows = [("Toán", 8.5, 9.0, 8.8), ("Ngữ văn", 7.5, 8.0, 7.8), ("Tiếng Anh", 9.0, 9.5, 9.3),
            ("Vật lý", 8.0, 8.5, 8.3), ("Hóa học", 7.0, 7.5, 7.3), ("Sinh học", 8.5, 8.0, 8.2),
            ("Lịch sử", 8.0, 9.0, 8.7), ("Tin học", 9.5, 10, 9.8)]
    for i, (m, a, b, c) in enumerate(rows):
        y = 238 + i * 36
        s.text(28, y, m, 13, 400, TXT)
        s.text(230, y, str(a), 13, 400, TXT, "middle")
        s.text(284, y, str(b), 13, 400, TXT, "middle")
        s.text(330, y, str(c), 13, 700, OR, "middle")
        s.line(16, y + 12, 344, y + 12, "#E4E6EB")
    s.text(180, 550, "Chạm vào môn học để xem chi tiết điểm", 11, 400, GRAY, "middle")
    out["05_ListGrade"] = s

    # 6 List request
    s = S()
    s.appbar("Đơn từ")
    x = 16
    for i, (f, w) in enumerate((("Tất cả", 64), ("Chờ duyệt", 82), ("Đã duyệt", 76), ("Từ chối", 70))):
        s.rect(x, 72, w, 28, OR if i == 0 else "#fff", None if i == 0 else BORDER, 14)
        s.text(x + w / 2, 91, f, 12, 600, "#fff" if i == 0 else GRAY, "middle")
        x += w + 8
    items = [("Đơn xin nghỉ học", "Nguyễn Văn An - 10A1", "Nghỉ 15/10 - 16/10/2026 (ốm)", "Chờ duyệt", "#FFF3CD", "#8A6D00"),
             ("Đơn xin nghỉ học", "Nguyễn Văn An - 10A1", "Nghỉ 02/10/2026 (việc gia đình)", "Đã duyệt", "#DDF3E4", GREEN),
             ("Xin đổi chỗ ngồi", "Trần Thị Mai - 10A1", "Gửi 25/09/2026", "Từ chối", "#FDE3E1", RED),
             ("Xin phép đi trễ", "Lê Minh Khoa - 10A2", "Ngày 12/10/2026", "Chờ duyệt", "#FFF3CD", "#8A6D00")]
    for i, (t, who, d, st, bg, fg) in enumerate(items):
        y = 116 + i * 100
        s.card(16, y, 328, 88)
        s.text(30, y + 26, t, 14, 700, TXT)
        s.chip(344 - 14 - 76, y + 12, st, bg, fg, 76)
        s.text(30, y + 48, who, 12, 400, GRAY)
        s.text(30, y + 68, d, 12, 400, GRAY)
    s.circle(312, 664, 28, OR)
    s.text(312, 674, "+", 30, 400, "#fff", "middle")
    out["06_ListRequest"] = s

    # 7 List club
    s = S()
    s.appbar("Câu lạc bộ")
    s.rect(16, 72, 328, 40, "#fff", BORDER, 20)
    s.text(40, 97, "Tìm câu lạc bộ", 13, 400, GRAY)
    clubs = [("CLB Bóng đá", "42 thành viên", "Đã tham gia"), ("CLB Âm nhạc", "28 thành viên", "Chờ duyệt"),
             ("CLB Lập trình", "56 thành viên", "Tham gia"), ("CLB Mỹ thuật", "19 thành viên", "Tham gia"),
             ("CLB Bóng rổ", "35 thành viên", "Tham gia")]
    for i, (n, m, st) in enumerate(clubs):
        y = 128 + i * 84
        s.card(16, y, 328, 72)
        s.circle(52, y + 36, 22, OR_SOFT)
        s.text(52, y + 42, "☺", 18, 400, OR, "middle")
        s.text(88, y + 32, n, 14, 700, TXT)
        s.text(88, y + 52, m, 12, 400, GRAY)
        s.chip(344 - 12 - 84, y + 25, st, OR_SOFT if st != "Đã tham gia" else "#DDF3E4", OR if st != "Đã tham gia" else GREEN, 84)
    out["07_ListClub"] = s

    # 8 Schedule detail
    s = S()
    s.appbar("Chi tiết tiết học")
    s.rect(16, 72, 328, 90, OR_SOFT, None, 12)
    s.text(32, 106, "Tiếng Anh", 22, 800, OR)
    s.text(32, 132, "Thứ Tư, 14/10/2026 - Tiết 1 (07:30 - 08:15)", 12, 400, GRAY)
    for i, (a, b) in enumerate((("Lớp", "10A1"), ("Phòng học", "P.305 - Tòa B"), ("Giáo viên", "Cô Nguyễn Thị Lan"),
                                ("Hình thức", "Trực tiếp"), ("Nội dung", "Unit 4: Environment"),
                                ("Chuẩn bị", "Sách + từ vựng Unit 4"))):
        s.row(200 + i * 40, a, b)
    s.card(16, 460, 328, 80)
    s.text(30, 486, "Ghi chú", 13, 700, TXT)
    s.text(30, 510, "Kiểm tra 15 phút đầu giờ. Mang theo vở bài tập.", 12, 400, GRAY)
    out["08_ViewScheduleDetail"] = s

    # 9 Grade detail
    s = S()
    s.appbar("Điểm môn Toán")
    s.rect(16, 72, 328, 90, OR, None, 12)
    s.text(32, 96, "Trung bình môn Toán - HK1", 12, 400, "#fff")
    s.text(32, 140, "8.8", 38, 800, "#fff")
    s.text(328, 140, "GV: Thầy Phạm Quốc Bảo", 12, 600, "#fff", "end")
    s.rect(16, 178, 328, 30, OR_SOFT, None, 6)
    for x, h_ in ((28, "Loại điểm"), (190, "Hệ số"), (250, "Điểm"), (320, "Ngày")):
        s.text(x, 198, h_, 11, 700, OR, "start" if x == 28 else "middle")
    rows = [("Miệng", 1, 9.0, "10/09"), ("15 phút", 1, 8.5, "24/09"), ("15 phút", 1, 9.0, "08/10"),
            ("1 tiết", 2, 8.5, "15/10"), ("Giữa kỳ", 2, 9.0, "28/10"), ("Cuối kỳ", 3, 9.0, "20/12")]
    for i, (a, b, c, d) in enumerate(rows):
        y = 232 + i * 36
        s.text(28, y, a, 13, 400, TXT)
        s.text(190, y, str(b), 13, 400, TXT, "middle")
        s.text(250, y, str(c), 13, 700, OR, "middle")
        s.text(320, y, d, 13, 400, GRAY, "middle")
        s.line(16, y + 12, 344, y + 12, "#E4E6EB")
    s.card(16, 460, 328, 80)
    s.text(30, 486, "Nhận xét của giáo viên", 13, 700, TXT)
    s.text(30, 510, "Em tiếp thu tốt, cần chú ý trình bày bài giải hình học.", 12, 400, GRAY)
    out["09_ViewGradeDetail"] = s

    # 10 Add request
    s = S()
    s.appbar("Tạo đơn mới")
    s.field(16, 92, 328, "Học sinh", "Nguyễn Văn An - 10A1  ▾")
    s.field(16, 168, 328, "Loại đơn", "Xin nghỉ học  ▾")
    s.field(16, 244, 156, "Từ ngày", "15/10/2026")
    s.field(188, 244, 156, "Đến ngày", "16/10/2026")
    s.text(16, 320, "Lý do", 12, 600, TXT)
    s.rect(16, 328, 328, 110, "#fff", BORDER, 10)
    s.text(30, 354, "Con bị sốt, xin phép cho con nghỉ học 2 ngày...", 13, 400, GRAY)
    s.rect(16, 454, 328, 44, "#fff", BORDER, 10)
    s.text(180, 481, "📎 Đính kèm giấy xác nhận (tùy chọn)", 12, 400, GRAY, "middle")
    s.button(16, 520, 328, "Gửi đơn")
    s.button(16, 580, 328, "Hủy", "#fff", OR, 48, OR)
    out["10_AddRequest"] = s

    # 11 Request detail (GV)
    s = S()
    s.appbar("Chi tiết đơn")
    s.text(16, 96, "Đơn xin nghỉ học", 18, 700, TXT)
    s.chip(344 - 76, 80, "Chờ duyệt", "#FFF3CD", "#8A6D00", 76)
    s.text(16, 120, "Gửi lúc 14/10/2026 - 20:15", 12, 400, GRAY)
    for i, (a, b) in enumerate((("Học sinh", "Nguyễn Văn An"), ("Lớp", "10A1"),
                                ("Người gửi", "Phụ huynh - Nguyễn Văn Bình"), ("Thời gian nghỉ", "15/10 - 16/10/2026"))):
        s.row(160 + i * 40, a, b)
    s.card(16, 336, 328, 90)
    s.text(30, 360, "Lý do", 13, 700, TXT)
    s.text(30, 384, "Con bị sốt, xin phép cho con nghỉ học 2 ngày", 12, 400, GRAY)
    s.text(30, 404, "để đi khám và nghỉ ngơi.", 12, 400, GRAY)
    s.text(16, 454, "Ý kiến giáo viên", 12, 600, TXT)
    s.rect(16, 462, 328, 70, "#fff", BORDER, 10)
    s.text(30, 488, "Nhập ý kiến (tùy chọn)...", 13, 400, GRAY)
    s.button(16, 580, 156, "Từ chối", RED)
    s.button(188, 580, 156, "Duyệt", GREEN)
    out["11_ViewRequestDetail"] = s

    # 12 Club detail
    s = S()
    s.appbar("CLB Lập trình")
    s.rect(0, 56, W, 150, OR_SOFT)
    s.text(180, 140, "</>", 48, 800, OR, "middle")
    s.text(16, 236, "CLB Lập trình", 20, 800, TXT)
    s.text(16, 258, "56 thành viên - Sinh hoạt T6, 15:30", 12, 400, GRAY)
    s.card(16, 276, 328, 90)
    s.text(30, 300, "Giới thiệu", 13, 700, TXT)
    s.text(30, 322, "Nơi học sinh yêu công nghệ cùng học Python,", 12, 400, GRAY)
    s.text(30, 342, "Flutter và tham gia các cuộc thi lập trình.", 12, 400, GRAY)
    for i, (a, b) in enumerate((("Chủ nhiệm CLB", "Thầy Lê Văn Hùng"), ("Địa điểm", "P.401 - Phòng máy"),
                                ("Chủ tịch", "Trần Minh Quân (11A2)"))):
        s.row(396 + i * 40, a, b)
    x = 16
    for t in ("QT", "LH", "MP", "+53"):
        s.circle(x + 20, 540, 20, OR_SOFT)
        s.text(x + 20, 545, t, 12, 700, OR, "middle")
        x += 48
    s.button(16, 640, 328, "Tham gia câu lạc bộ")
    out["12_ViewClubDetail"] = s
    return out


if __name__ == "__main__":
    here = os.path.dirname(os.path.abspath(__file__))
    for name, s in screens().items():
        with open(os.path.join(here, f"{name}.svg"), "w", encoding="utf-8") as f:
            f.write(s.build(name))
    print("wrote", len(screens()), "svgs to", here)
