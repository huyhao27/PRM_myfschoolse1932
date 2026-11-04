<%@ Page Title="Nhập Điểm Môn Học" Language="C#" MasterPageFile="~/Site.Master" AutoEventWireup="true" CodeBehind="AddGrade.aspx.cs" Inherits="MyfschoolWeb.AddGrade" ResponseEncoding="utf-8" ContentType="text/html; charset=utf-8" %>

<asp:Content ID="BodyContent" ContentPlaceHolderID="MainContent" runat="server">
    <div class="row justify-content-center">
        <div class="col-lg-9 col-md-11">
            <div class="d-flex justify-content-between align-items-center mb-4 flex-wrap gap-2">
                <div>
                    <h3 class="fw-bold text-navy mb-1"><i class="fa-solid fa-file-pen text-primary me-2"></i>Nhập Điểm Môn Học</h3>
                    <p class="text-muted mb-0">Điểm trung bình được tính theo hệ số, trùng với ứng dụng di động</p>
                </div>
                <a href="ListGrade.aspx" class="btn btn-outline-secondary"><i class="fa-solid fa-arrow-left me-1"></i> Quay lại sổ điểm</a>
            </div>

            <!-- THÔNG BÁO ALERT -->
            <asp:Panel ID="pnlAlert" runat="server" Visible="false" CssClass="alert alert-danger alert-dismissible fade show" role="alert">
                <asp:Literal ID="litAlertMessage" runat="server"></asp:Literal>
                <button type="button" class="btn-close" data-bs-dismiss="alert" aria-label="Close"></button>
            </asp:Panel>

            <div class="card card-custom p-4">
                <div class="row g-3 mb-4">
                    <div class="col-12 border-bottom pb-2">
                        <h5 class="fw-bold text-primary mb-0"><i class="fa-solid fa-user-graduate me-2"></i>1. Thông Tin Học Sinh & Lớp Học</h5>
                    </div>

                    <div class="col-md-4">
                        <label class="form-label fw-semibold">Lớp học (*)</label>
                        <asp:DropDownList ID="ddlClass" runat="server" CssClass="form-select" AutoPostBack="true" OnSelectedIndexChanged="ddlClass_SelectedIndexChanged">
                        </asp:DropDownList>
                    </div>

                    <div class="col-md-8">
                        <label class="form-label fw-semibold">Học sinh (*)</label>
                        <asp:DropDownList ID="ddlStudent" runat="server" CssClass="form-select">
                        </asp:DropDownList>
                    </div>
                </div>

                <div class="row g-3 mb-4">
                    <div class="col-12 border-bottom pb-2">
                        <h5 class="fw-bold text-primary mb-0"><i class="fa-solid fa-book me-2"></i>2. Môn Học & Học Kỳ</h5>
                    </div>

                    <div class="col-md-5">
                        <label class="form-label fw-semibold">Môn học (*)</label>
                        <asp:DropDownList ID="ddlSubject" runat="server" CssClass="form-select"></asp:DropDownList>
                        <small class="text-muted">Giáo viên chỉ nhập được môn mình dạy trong lớp (theo thời khóa biểu).</small>
                    </div>

                    <div class="col-md-4">
                        <asp:Panel ID="pnlOtherSubject" runat="server" Visible="false">
                            <label class="form-label fw-semibold">Môn khác (Quản lý nhập tên)</label>
                            <asp:TextBox ID="txtSubjectOther" runat="server" CssClass="form-control" MaxLength="100" placeholder="Để trống nếu chọn ở danh sách"></asp:TextBox>
                        </asp:Panel>
                    </div>

                    <div class="col-md-3">
                        <label class="form-label fw-semibold">Học kỳ (*)</label>
                        <asp:DropDownList ID="ddlTerm" runat="server" CssClass="form-select"></asp:DropDownList>
                    </div>
                </div>

                <div class="row g-3 mb-4">
                    <div class="col-12 border-bottom pb-2 d-flex justify-content-between align-items-center flex-wrap gap-2">
                        <h5 class="fw-bold text-primary mb-0"><i class="fa-solid fa-calculator me-2"></i>3. Điểm Đánh Giá (Thang Điểm 0 - 10)</h5>
                        <small class="text-muted"><i class="fa-solid fa-circle-info me-1"></i>Hệ số: Miệng=1, 15 phút=1, 1 tiết=2, Giữa kỳ=2, Cuối kỳ=3 (ô trống = chưa có điểm)</small>
                    </div>

                    <div class="col-md-3">
                        <label class="form-label fw-semibold">Miệng</label>
                        <asp:TextBox ID="txtOral" runat="server" CssClass="form-control score-input" data-weight="1"></asp:TextBox>
                        <small class="text-muted">Hệ số 1</small>
                    </div>
                    <div class="col-md-3">
                        <label class="form-label fw-semibold">15 phút (lần 1)</label>
                        <asp:TextBox ID="txt15a" runat="server" CssClass="form-control score-input" data-weight="1"></asp:TextBox>
                        <small class="text-muted">Hệ số 1</small>
                    </div>
                    <div class="col-md-3">
                        <label class="form-label fw-semibold">15 phút (lần 2)</label>
                        <asp:TextBox ID="txt15b" runat="server" CssClass="form-control score-input" data-weight="1"></asp:TextBox>
                        <small class="text-muted">Hệ số 1</small>
                    </div>
                    <div class="col-md-3">
                        <label class="form-label fw-semibold">1 tiết</label>
                        <asp:TextBox ID="txt1t" runat="server" CssClass="form-control score-input" data-weight="2"></asp:TextBox>
                        <small class="text-muted">Hệ số 2</small>
                    </div>

                    <div class="col-md-6">
                        <label class="form-label fw-semibold text-primary">Giữa Kỳ (Hệ số 2)</label>
                        <asp:TextBox ID="txtGk" runat="server" CssClass="form-control score-input border-primary" data-weight="2"></asp:TextBox>
                    </div>

                    <div class="col-md-6">
                        <label class="form-label fw-semibold text-danger">Cuối Kỳ (Hệ số 3)</label>
                        <asp:TextBox ID="txtCk" runat="server" CssClass="form-control score-input border-danger" data-weight="3"></asp:TextBox>
                    </div>
                </div>

                <!-- LIVE PREVIEW -->
                <div class="p-3 mb-4 rounded-3 border bg-light d-flex justify-content-between align-items-center flex-wrap gap-3">
                    <div>
                        <div class="text-muted small fw-semibold">ĐIỂM TRUNG BÌNH MÔN (TÍNH NHẨM, GIỐNG ỨNG DỤNG):</div>
                        <div class="small text-muted font-monospace">ĐTB = Σ(điểm × hệ số) / Σ hệ số, làm tròn 2 chữ số</div>
                    </div>
                    <div class="text-end">
                        <span class="fs-4 fw-bold text-primary me-3" id="liveDtb">-</span>
                        <span class="badge bg-secondary fs-6" id="liveLevel">-</span>
                    </div>
                </div>

                <div class="mb-4">
                    <label class="form-label fw-semibold"><i class="fa-solid fa-comment-dots me-1"></i>Nhận xét của Giáo viên bộ môn</label>
                    <asp:TextBox ID="txtComment" runat="server" TextMode="MultiLine" Rows="3" MaxLength="300" CssClass="form-control"></asp:TextBox>
                </div>

                <div class="d-flex justify-content-end gap-2">
                    <a href="ListGrade.aspx" class="btn btn-outline-secondary px-4">Hủy Bỏ</a>
                    <asp:Button ID="btnSave" runat="server" Text="Lưu Sổ Điểm" CssClass="btn btn-fpt px-4" OnClick="btnSave_Click" />
                </div>
            </div>
        </div>
    </div>
</asp:Content>

<asp:Content ID="Scripts" ContentPlaceHolderID="ScriptsContent" runat="server">
    <script>
        function calculateLiveDtb() {
            var sum = 0, w = 0;
            document.querySelectorAll('.score-input').forEach(function (inp) {
                var v = (inp.value || '').replace(',', '.').trim();
                if (v === '') return;
                var x = parseFloat(v);
                if (isNaN(x)) return;
                var wt = parseInt(inp.getAttribute('data-weight'), 10) || 1;
                sum += x * wt; w += wt;
            });
            var dtbEl = document.getElementById('liveDtb');
            var levelSpan = document.getElementById('liveLevel');
            if (w === 0) { dtbEl.innerText = '-'; levelSpan.innerText = '-'; levelSpan.className = 'badge bg-secondary fs-6'; return; }
            var dtb = Math.round((sum / w) * 100) / 100;
            dtbEl.innerText = dtb.toFixed(2);
            if (dtb >= 8.0) { levelSpan.innerText = 'Tốt'; levelSpan.className = 'badge bg-success fs-6'; }
            else if (dtb >= 6.5) { levelSpan.innerText = 'Khá'; levelSpan.className = 'badge bg-primary fs-6'; }
            else if (dtb >= 5.0) { levelSpan.innerText = 'Đạt'; levelSpan.className = 'badge bg-warning text-dark fs-6'; }
            else { levelSpan.innerText = 'Chưa đạt'; levelSpan.className = 'badge bg-danger fs-6'; }
        }
        document.querySelectorAll('.score-input').forEach(function (inp) { inp.addEventListener('input', calculateLiveDtb); });
        calculateLiveDtb();
    </script>
</asp:Content>
