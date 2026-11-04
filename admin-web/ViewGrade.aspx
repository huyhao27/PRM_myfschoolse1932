<%@ Page Title="Chi Tiết Phiếu Điểm" Language="C#" MasterPageFile="~/Site.Master" AutoEventWireup="true" CodeBehind="ViewGrade.aspx.cs" Inherits="MyfschoolWeb.ViewGrade" ResponseEncoding="utf-8" ContentType="text/html; charset=utf-8" %>

<asp:Content ID="BodyContent" ContentPlaceHolderID="MainContent" runat="server">
    <div class="row justify-content-center">
        <div class="col-lg-8 col-md-10">
            <div class="d-flex justify-content-between align-items-center mb-4 flex-wrap gap-2 d-print-none">
                <div>
                    <h3 class="fw-bold text-navy mb-1"><i class="fa-solid fa-file-invoice text-info me-2"></i>Phiếu Điểm Môn Học Cá Nhân</h3>
                    <p class="text-muted mb-0">Hồ sơ kết quả học tập môn học theo học kỳ</p>
                </div>
                <div class="d-flex gap-2">
                    <asp:HyperLink ID="lnkEdit" runat="server" Visible="false" CssClass="btn btn-outline-warning"><i class="fa-solid fa-pen-to-square me-1"></i> Chỉnh sửa</asp:HyperLink>
                    <button type="button" class="btn btn-outline-primary" onclick="window.print();"><i class="fa-solid fa-print me-1"></i> In Phiếu Điểm</button>
                    <a href="ListGrade.aspx" class="btn btn-outline-secondary"><i class="fa-solid fa-arrow-left me-1"></i> Quay lại</a>
                </div>
            </div>

            <asp:Panel ID="pnlMessage" runat="server" Visible="false" CssClass="alert alert-warning">
                <asp:Literal ID="litMessage" runat="server"></asp:Literal>
            </asp:Panel>

            <!-- PHIẾU ĐIỂM CARD -->
            <asp:Panel ID="pnlCard" runat="server" CssClass="card card-custom p-4 p-md-5 print-card">
                <div class="text-center border-bottom pb-4 mb-4">
                    <h6 class="text-uppercase text-muted fw-bold mb-1">SỞ GIÁO DỤC VÀ ĐÀO TẠO HÀ NỘI</h6>
                    <h4 class="fw-bold text-navy mb-1">TRƯỜNG THPT FPT HÀ NỘI</h4>
                    <p class="text-muted small mb-0">Khu CNC Hòa Lạc, Thạch Thất, Hà Nội - Hotline: 024 7300 1866</p>
                    <h5 class="fw-bold text-primary mt-3 text-uppercase">PHIẾU ĐÁNH GIÁ KẾT QUẢ HỌC TẬP MÔN HỌC</h5>
                    <div class="badge bg-light text-dark border px-3 py-2 mt-1">
                        <asp:Literal ID="litTerm" runat="server"></asp:Literal>
                    </div>
                </div>

                <div class="row g-3 mb-4 bg-light p-3 rounded-3 border">
                    <div class="col-sm-6">
                        <div class="small text-muted">Họ và tên học sinh:</div>
                        <div class="fw-bold fs-5 text-dark"><asp:Literal ID="litStudentName" runat="server"></asp:Literal></div>
                    </div>
                    <div class="col-sm-3">
                        <div class="small text-muted">Mã số học sinh:</div>
                        <div class="fw-bold text-primary fs-6"><asp:Literal ID="litStudentId" runat="server"></asp:Literal></div>
                    </div>
                    <div class="col-sm-3">
                        <div class="small text-muted">Lớp:</div>
                        <div class="fw-bold text-dark fs-6"><asp:Literal ID="litClassName" runat="server"></asp:Literal></div>
                    </div>
                    <div class="col-sm-6">
                        <div class="small text-muted">Môn học:</div>
                        <div class="fw-semibold text-dark"><asp:Literal ID="litSubject" runat="server"></asp:Literal></div>
                    </div>
                    <div class="col-sm-6">
                        <div class="small text-muted">Giáo viên nhận xét:</div>
                        <div class="fw-semibold text-dark"><asp:Literal ID="litTeacherName" runat="server"></asp:Literal></div>
                    </div>
                </div>

                <!-- BẢNG ĐIỂM TỪNG ĐẦU ĐIỂM -->
                <div class="table-responsive mb-4">
                    <table class="table table-bordered text-center align-middle">
                        <thead class="table-light">
                            <tr>
                                <th>Loại điểm</th>
                                <th>Hệ số</th>
                                <th>Điểm</th>
                                <th>Ngày</th>
                            </tr>
                        </thead>
                        <tbody>
                            <asp:Repeater ID="rptEntries" runat="server">
                                <ItemTemplate>
                                    <tr>
                                        <td><%# Eval("Type") %></td>
                                        <td><%# Eval("Weight") %></td>
                                        <td class="fw-bold"><%# Eval("ScoreText") %></td>
                                        <td class="small text-muted"><%# Eval("DateText") %></td>
                                    </tr>
                                </ItemTemplate>
                            </asp:Repeater>
                        </tbody>
                        <tfoot>
                            <tr class="table-primary">
                                <td colspan="2" class="fw-semibold">Điểm trung bình môn (ĐTB)</td>
                                <td class="fs-4 fw-bold text-primary"><asp:Literal ID="litAverage" runat="server">-</asp:Literal></td>
                                <td><span class='<asp:Literal ID="litBadgeClass" runat="server"></asp:Literal> fs-6 px-3 py-2'><asp:Literal ID="litLevel" runat="server">-</asp:Literal></span></td>
                            </tr>
                        </tfoot>
                    </table>
                </div>

                <div class="mb-4">
                    <div class="small text-muted fw-semibold mb-1">CÔNG THỨC TÍNH ĐIỂM:</div>
                    <div class="p-2 border rounded bg-light font-monospace small">
                        ĐTB = Σ(điểm × hệ số) / Σ hệ số = <asp:Literal ID="litFormulaCalc" runat="server"></asp:Literal>
                    </div>
                    <div class="small text-muted mt-2">Hạnh kiểm học kỳ: <strong><asp:Literal ID="litConduct" runat="server">-</asp:Literal></strong></div>
                </div>

                <div class="mb-5">
                    <div class="small text-muted fw-semibold mb-1"><i class="fa-solid fa-comment-dots me-1"></i>NHẬN XÉT & ĐÁNH GIÁ CỦA GIÁO VIÊN BỘ MÔN:</div>
                    <div class="p-3 border rounded bg-light fst-italic">
                        "<asp:Literal ID="litComment" runat="server"></asp:Literal>"
                    </div>
                </div>

                <div class="row text-center mt-4">
                    <div class="col-6">
                        <div class="small text-muted">Học sinh xác nhận</div>
                        <div class="fw-semibold mt-1"><asp:Literal ID="litSignStudent" runat="server"></asp:Literal></div>
                    </div>
                    <div class="col-6">
                        <div class="small text-muted">Hà Nội, ngày <%: DateTime.Now.ToString("dd/MM/yyyy") %></div>
                        <div class="small text-muted">Giáo viên bộ môn ký duyệt</div>
                        <div class="fw-semibold mt-1"><asp:Literal ID="litSignTeacher" runat="server"></asp:Literal></div>
                    </div>
                </div>
            </asp:Panel>
        </div>
    </div>
</asp:Content>
