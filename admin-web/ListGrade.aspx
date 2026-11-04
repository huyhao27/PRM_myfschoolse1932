<%@ Page Title="Sổ Điểm Lớp" Language="C#" MasterPageFile="~/Site.Master" AutoEventWireup="true" CodeBehind="ListGrade.aspx.cs" Inherits="MyfschoolWeb.ListGrade" ResponseEncoding="utf-8" ContentType="text/html; charset=utf-8" %>

<asp:Content ID="BodyContent" ContentPlaceHolderID="MainContent" runat="server">
    <div class="d-flex justify-content-between align-items-center mb-4 flex-wrap gap-2">
        <div>
            <h3 class="fw-bold text-navy mb-1"><i class="fa-solid fa-book-bookmark text-primary me-2"></i>Sổ Điểm Điện Tử</h3>
            <p class="text-muted mb-0">Điểm từng môn theo học kỳ, điểm trung bình tính theo hệ số (trùng với ứng dụng di động)</p>
        </div>
        <div class="d-flex gap-2">
            <a href="AddGrade.aspx" class="btn btn-fpt"><i class="fa-solid fa-plus me-1"></i> Nhập Điểm Mới</a>
            <a href="ImportData.aspx" class="btn btn-outline-secondary"><i class="fa-solid fa-file-excel me-1"></i> Import Điểm</a>
        </div>
    </div>

    <asp:Panel ID="pnlAlert" runat="server" Visible="false" CssClass="alert alert-success alert-dismissible fade show" role="alert">
        <asp:Literal ID="litAlertMessage" runat="server"></asp:Literal>
        <button type="button" class="btn-close" data-bs-dismiss="alert" aria-label="Close"></button>
    </asp:Panel>

    <!-- BỘ LỌC TÌM KIẾM -->
    <div class="card card-custom p-3 mb-4">
        <div class="row g-2 align-items-end">
            <div class="col-md-3 col-sm-6">
                <label class="form-label small fw-semibold">Lớp học:</label>
                <asp:DropDownList ID="ddlClass" runat="server" CssClass="form-select form-select-sm" AutoPostBack="true" OnSelectedIndexChanged="FilterChanged">
                </asp:DropDownList>
            </div>
            <div class="col-md-3 col-sm-6">
                <label class="form-label small fw-semibold">Môn học:</label>
                <asp:DropDownList ID="ddlSubject" runat="server" CssClass="form-select form-select-sm" AutoPostBack="true" OnSelectedIndexChanged="FilterChanged">
                </asp:DropDownList>
            </div>
            <div class="col-md-2 col-sm-6">
                <label class="form-label small fw-semibold">Học kỳ:</label>
                <asp:DropDownList ID="ddlTerm" runat="server" CssClass="form-select form-select-sm" AutoPostBack="true" OnSelectedIndexChanged="FilterChanged">
                </asp:DropDownList>
            </div>
            <div class="col-md-3 col-sm-6">
                <label class="form-label small fw-semibold">Tìm kiếm học sinh:</label>
                <asp:TextBox ID="txtSearch" runat="server" CssClass="form-control form-control-sm" placeholder="Mã HS hoặc Họ tên..."></asp:TextBox>
            </div>
            <div class="col-md-1 col-sm-12 d-grid">
                <asp:Button ID="btnSearch" runat="server" Text="Lọc" CssClass="btn btn-sm btn-primary" OnClick="btnSearch_Click" />
            </div>
        </div>
    </div>

    <!-- BẢNG DỮ LIỆU ĐIỂM SỐ -->
    <div class="card card-custom">
        <div class="card-header-fpt">
            <span>
                <i class="fa-solid fa-table-list me-2"></i>Bảng Tổng Hợp Điểm Số
                <span class="badge bg-secondary ms-2"><asp:Literal ID="litRecordCount" runat="server">0</asp:Literal> bảng điểm</span>
            </span>
            <div class="small text-muted">
                <span class="badge bg-light text-dark border me-1">Miệng/15p: HS 1</span>
                <span class="badge bg-light text-dark border me-1">1 tiết, GK: HS 2</span>
                <span class="badge bg-light text-dark border">CK: HS 3</span>
            </div>
        </div>
        <div class="table-responsive">
            <asp:GridView ID="gvGrades" runat="server" AutoGenerateColumns="False"
                CssClass="table table-hover table-custom align-middle mb-0" GridLines="None"
                OnRowCommand="gvGrades_RowCommand" OnRowDataBound="gvGrades_RowDataBound">
                <Columns>
                    <asp:BoundField DataField="ClassName" HeaderText="Lớp" HeaderStyle-CssClass="text-center" ItemStyle-CssClass="text-center fw-bold text-primary" />
                    <asp:BoundField DataField="StudentId" HeaderText="Mã HS" HeaderStyle-CssClass="text-center" ItemStyle-CssClass="text-center fw-semibold" />
                    <asp:BoundField DataField="StudentName" HeaderText="Họ và Tên" />
                    <asp:BoundField DataField="Subject" HeaderText="Môn Học" />
                    <asp:BoundField DataField="Term" HeaderText="Học Kỳ" HeaderStyle-CssClass="text-center" ItemStyle-CssClass="text-center small text-muted" />
                    <asp:BoundField DataField="RegularText" HeaderText="Thường xuyên" HeaderStyle-CssClass="text-center" ItemStyle-CssClass="text-center" />
                    <asp:BoundField DataField="MidtermText" HeaderText="Giữa kỳ (x2)" HeaderStyle-CssClass="text-center" ItemStyle-CssClass="text-center fw-semibold text-dark" />
                    <asp:BoundField DataField="FinalText" HeaderText="Cuối kỳ (x3)" HeaderStyle-CssClass="text-center" ItemStyle-CssClass="text-center fw-semibold text-dark" />
                    <asp:BoundField DataField="AverageText" HeaderText="ĐTB" HeaderStyle-CssClass="text-center text-primary" ItemStyle-CssClass="text-center fw-bold fs-6 text-primary" />

                    <asp:TemplateField HeaderText="Xếp Loại" HeaderStyle-CssClass="text-center" ItemStyle-CssClass="text-center">
                        <ItemTemplate>
                            <span class='<%# Eval("BadgeClass") %>'><%# Eval("Evaluation") %></span>
                        </ItemTemplate>
                    </asp:TemplateField>

                    <asp:TemplateField HeaderText="Thao Tác" HeaderStyle-CssClass="text-center" ItemStyle-CssClass="text-center text-nowrap">
                        <ItemTemplate>
                            <asp:HyperLink ID="lnkView" runat="server" CssClass="btn btn-sm btn-outline-info me-1" ToolTip="Xem chi tiết"><i class="fa-solid fa-eye"></i></asp:HyperLink>
                            <asp:HyperLink ID="lnkEdit" runat="server" CssClass="btn btn-sm btn-outline-warning me-1" ToolTip="Chỉnh sửa"><i class="fa-solid fa-pen-to-square"></i></asp:HyperLink>
                            <asp:LinkButton ID="btnDelete" runat="server" CommandName="DeleteGrade" CssClass="btn btn-sm btn-outline-danger" ToolTip="Xóa bảng điểm"
                                OnClientClick="return confirm('Bạn có chắc chắn muốn xóa toàn bộ điểm môn này của học sinh không?');">
                                <i class="fa-solid fa-trash"></i>
                            </asp:LinkButton>
                        </ItemTemplate>
                    </asp:TemplateField>
                </Columns>
                <EmptyDataTemplate>
                    <div class="text-center py-5">
                        <i class="fa-solid fa-folder-open fa-3x text-muted mb-3"></i>
                        <h6 class="text-muted">Không tìm thấy dữ liệu điểm nào phù hợp với bộ lọc.</h6>
                        <a href="AddGrade.aspx" class="btn btn-sm btn-fpt mt-2"><i class="fa-solid fa-plus me-1"></i> Nhập điểm ngay</a>
                    </div>
                </EmptyDataTemplate>
            </asp:GridView>
        </div>
    </div>
</asp:Content>
