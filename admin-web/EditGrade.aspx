<%@ Page Title="Chỉnh Sửa Điểm Môn Học" Language="C#" MasterPageFile="~/Site.Master" AutoEventWireup="true" CodeBehind="EditGrade.aspx.cs" Inherits="MyfschoolWeb.EditGrade" ResponseEncoding="utf-8" ContentType="text/html; charset=utf-8" %>

<asp:Content ID="BodyContent" ContentPlaceHolderID="MainContent" runat="server">
    <div class="row justify-content-center">
        <div class="col-lg-9 col-md-11">
            <div class="d-flex justify-content-between align-items-center mb-4 flex-wrap gap-2">
                <div>
                    <h3 class="fw-bold text-navy mb-1"><i class="fa-solid fa-pen-to-square text-warning me-2"></i>Chỉnh Sửa Điểm Môn Học</h3>
                    <p class="text-muted mb-0">Sửa, thêm hoặc xóa từng đầu điểm của học sinh trong học kỳ</p>
                </div>
                <a href="ListGrade.aspx" class="btn btn-outline-secondary"><i class="fa-solid fa-arrow-left me-1"></i> Quay lại sổ điểm</a>
            </div>

            <asp:Panel ID="pnlAlert" runat="server" Visible="false" CssClass="alert alert-danger alert-dismissible fade show" role="alert">
                <asp:Literal ID="litAlertMessage" runat="server"></asp:Literal>
                <button type="button" class="btn-close" data-bs-dismiss="alert" aria-label="Close"></button>
            </asp:Panel>

            <asp:Panel ID="pnlForm" runat="server" CssClass="card card-custom p-4">
                <div class="row g-3 mb-4">
                    <div class="col-12 border-bottom pb-2">
                        <h5 class="fw-bold text-primary mb-0"><i class="fa-solid fa-user-graduate me-2"></i>1. Học Sinh & Môn Học</h5>
                    </div>
                    <div class="col-md-3">
                        <label class="form-label fw-semibold">Mã học sinh</label>
                        <asp:TextBox ID="txtStudentId" runat="server" CssClass="form-control bg-light" ReadOnly="true"></asp:TextBox>
                    </div>
                    <div class="col-md-5">
                        <label class="form-label fw-semibold">Họ và tên</label>
                        <asp:TextBox ID="txtStudentName" runat="server" CssClass="form-control bg-light" ReadOnly="true"></asp:TextBox>
                    </div>
                    <div class="col-md-4">
                        <label class="form-label fw-semibold">Lớp học</label>
                        <asp:TextBox ID="txtClassName" runat="server" CssClass="form-control bg-light" ReadOnly="true"></asp:TextBox>
                    </div>
                    <div class="col-md-6">
                        <label class="form-label fw-semibold">Môn học</label>
                        <asp:TextBox ID="txtSubject" runat="server" CssClass="form-control bg-light" ReadOnly="true"></asp:TextBox>
                    </div>
                    <div class="col-md-6">
                        <label class="form-label fw-semibold">Học kỳ</label>
                        <asp:TextBox ID="txtTerm" runat="server" CssClass="form-control bg-light" ReadOnly="true"></asp:TextBox>
                    </div>
                </div>

                <div class="row g-3 mb-4">
                    <div class="col-12 border-bottom pb-2 d-flex justify-content-between align-items-center flex-wrap gap-2">
                        <h5 class="fw-bold text-primary mb-0"><i class="fa-solid fa-calculator me-2"></i>2. Các Đầu Điểm</h5>
                        <small class="text-muted">Hệ số: Miệng=1, 15 phút=1, 1 tiết=2, Giữa kỳ=2, Cuối kỳ=3</small>
                    </div>
                    <div class="col-12">
                        <div class="table-responsive">
                            <table class="table align-middle mb-2">
                                <thead class="table-light">
                                    <tr><th>Loại điểm</th><th style="width:140px">Điểm (0-10)</th><th style="width:170px">Ngày</th><th style="width:70px" class="text-center">Xóa</th></tr>
                                </thead>
                                <tbody>
                                    <asp:Repeater ID="rptRows" runat="server" OnItemDataBound="rptRows_ItemDataBound">
                                        <ItemTemplate>
                                            <tr>
                                                <td><asp:DropDownList ID="ddlType" runat="server" CssClass="form-select form-select-sm row-type"></asp:DropDownList></td>
                                                <td><asp:TextBox ID="txtScore" runat="server" CssClass="form-control form-control-sm row-score" Text='<%# Eval("ScoreText") %>'></asp:TextBox></td>
                                                <td><asp:TextBox ID="txtDate" runat="server" CssClass="form-control form-control-sm" TextMode="Date" Text='<%# Eval("DateText") %>'></asp:TextBox></td>
                                                <td class="text-center"><asp:CheckBox ID="chkDel" runat="server" CssClass="row-del" /></td>
                                            </tr>
                                        </ItemTemplate>
                                    </asp:Repeater>
                                </tbody>
                            </table>
                        </div>
                        <asp:Button ID="btnAddRow" runat="server" Text="+ Thêm đầu điểm" CssClass="btn btn-sm btn-outline-primary" OnClick="btnAddRow_Click" CausesValidation="false" />
                    </div>
                </div>

                <div class="p-3 mb-4 rounded-3 border bg-light d-flex justify-content-between align-items-center flex-wrap gap-3">
                    <div>
                        <div class="text-muted small fw-semibold">ĐIỂM TRUNG BÌNH MÔN SAU KHI SỬA:</div>
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
                    <asp:Button ID="btnUpdate" runat="server" Text="Lưu Thay Đổi" CssClass="btn btn-fpt px-4" OnClick="btnUpdate_Click" />
                </div>
            </asp:Panel>
        </div>
    </div>
</asp:Content>

<asp:Content ID="Scripts" ContentPlaceHolderID="ScriptsContent" runat="server">
    <script>
        var WEIGHTS = { 'Miệng': 1, '15 phút': 1, '1 tiết': 2, 'Giữa kỳ': 2, 'Cuối kỳ': 3 };
        function calculateLiveDtb() {
            var sum = 0, w = 0;
            document.querySelectorAll('tbody tr').forEach(function (tr) {
                var sel = tr.querySelector('.row-type'), sc = tr.querySelector('.row-score'), del = tr.querySelector('.row-del input');
                if (!sel || !sc || (del && del.checked)) return;
                var v = (sc.value || '').replace(',', '.').trim();
                if (v === '') return;
                var x = parseFloat(v);
                if (isNaN(x)) return;
                var wt = WEIGHTS[sel.value] || 1;
                sum += x * wt; w += wt;
            });
            var dtbEl = document.getElementById('liveDtb');
            var levelSpan = document.getElementById('liveLevel');
            if (!dtbEl) return;
            if (w === 0) { dtbEl.innerText = '-'; levelSpan.innerText = '-'; levelSpan.className = 'badge bg-secondary fs-6'; return; }
            var dtb = Math.round((sum / w) * 100) / 100;
            dtbEl.innerText = dtb.toFixed(2);
            if (dtb >= 8.0) { levelSpan.innerText = 'Tốt'; levelSpan.className = 'badge bg-success fs-6'; }
            else if (dtb >= 6.5) { levelSpan.innerText = 'Khá'; levelSpan.className = 'badge bg-primary fs-6'; }
            else if (dtb >= 5.0) { levelSpan.innerText = 'Đạt'; levelSpan.className = 'badge bg-warning text-dark fs-6'; }
            else { levelSpan.innerText = 'Chưa đạt'; levelSpan.className = 'badge bg-danger fs-6'; }
        }
        document.addEventListener('input', calculateLiveDtb);
        document.addEventListener('change', calculateLiveDtb);
        calculateLiveDtb();
    </script>
</asp:Content>
