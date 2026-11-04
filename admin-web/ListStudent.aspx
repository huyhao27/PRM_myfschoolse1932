<%@ Page Title="Quản Lý Hồ Sơ & Tài Khoản" Language="C#" MasterPageFile="~/Site.Master" AutoEventWireup="true" CodeBehind="ListStudent.aspx.cs" Inherits="MyfschoolWeb.ListStudent" ResponseEncoding="utf-8" ContentType="text/html; charset=utf-8" %>

<asp:Content ID="BodyContent" ContentPlaceHolderID="MainContent" runat="server">
    <!-- HEADER -->
    <div class="d-flex justify-content-between align-items-center mb-4 flex-wrap gap-2">
        <div>
            <h3 class="fw-bold text-navy mb-1"><i class="fa-solid fa-users-gear text-primary me-2"></i>Quản Lý Hồ Sơ & Tài Khoản FSchool</h3>
            <p class="text-muted mb-0"><asp:Literal ID="litSubtitle" runat="server"></asp:Literal></p>
        </div>
        <div class="d-flex gap-2">
            <asp:PlaceHolder ID="phAdminActions" runat="server">
                <asp:LinkButton ID="btnShowAdd" runat="server" CssClass="btn btn-success fw-semibold shadow-sm" OnClick="btnShowAdd_Click" CausesValidation="false">
                    <i class="fa-solid fa-user-plus me-1"></i> + Thêm Tài Khoản
                </asp:LinkButton>
                <a href="ImportData.aspx" class="btn btn-fpt"><i class="fa-solid fa-file-import me-1"></i> Import Dữ Liệu</a>
            </asp:PlaceHolder>
        </div>
    </div>

    <asp:Panel ID="pnlStatusAlert" runat="server" Visible="false" CssClass="alert alert-dismissible fade show mb-4 shadow-sm" role="alert">
        <asp:Literal ID="litStatusMessage" runat="server"></asp:Literal>
        <button type="button" class="btn-close" data-bs-dismiss="alert" aria-label="Close"></button>
    </asp:Panel>

    <!-- FORM: CREATE / EDIT (Manager) -->
    <asp:Panel ID="pnlForm" runat="server" Visible="false" CssClass="card card-custom p-3 mb-4 border-start border-4 border-success">
        <asp:HiddenField ID="hfEditId" runat="server" />
        <h5 class="fw-bold text-navy mb-3"><asp:Literal ID="litFormTitle" runat="server"></asp:Literal></h5>
        <div class="row g-3">
            <div class="col-md-3">
                <label class="form-label fw-semibold small">Vai trò (*):</label>
                <asp:DropDownList ID="ddlFormRole" runat="server" CssClass="form-select form-select-sm">
                    <asp:ListItem Value="HS" Text="Học sinh (HS)" Selected="True"></asp:ListItem>
                    <asp:ListItem Value="GV" Text="Giáo viên (GV)"></asp:ListItem>
                    <asp:ListItem Value="PH" Text="Phụ huynh (PH)"></asp:ListItem>
                    <asp:ListItem Value="Manager" Text="Quản lý (Manager)"></asp:ListItem>
                </asp:DropDownList>
            </div>
            <div class="col-md-5">
                <label class="form-label fw-semibold small">Họ và tên (*):</label>
                <asp:TextBox ID="txtName" runat="server" CssClass="form-control form-control-sm" MaxLength="100" placeholder="Ví dụ: Nguyễn Hải Đăng"></asp:TextBox>
            </div>
            <div class="col-md-4">
                <label class="form-label fw-semibold small">Lớp (học sinh / GV chủ nhiệm):</label>
                <asp:TextBox ID="txtClass" runat="server" CssClass="form-control form-control-sm" MaxLength="20" placeholder="Ví dụ: 10A1"></asp:TextBox>
            </div>
            <div class="col-md-4">
                <label class="form-label fw-semibold small">Số điện thoại (đăng nhập):</label>
                <asp:TextBox ID="txtPhone" runat="server" CssClass="form-control form-control-sm" MaxLength="20" placeholder="9-11 chữ số, ví dụ 0987654321"></asp:TextBox>
            </div>
            <div class="col-md-4">
                <label class="form-label fw-semibold small">Email:</label>
                <asp:TextBox ID="txtEmail" runat="server" CssClass="form-control form-control-sm" MaxLength="150" placeholder="ten@fpt.edu.vn"></asp:TextBox>
            </div>
            <div class="col-md-4">
                <asp:PlaceHolder ID="phPassword" runat="server">
                    <label class="form-label fw-semibold small">Mật khẩu khởi tạo:</label>
                    <asp:TextBox ID="txtPassword" runat="server" CssClass="form-control form-control-sm" MaxLength="72" Text="123456"></asp:TextBox>
                </asp:PlaceHolder>
            </div>
        </div>
        <div class="form-text small mb-3">Cần ít nhất số điện thoại hoặc email. Số điện thoại và email không được trùng với tài khoản khác.</div>
        <div class="d-flex gap-2">
            <asp:Button ID="btnSaveUser" runat="server" Text="Lưu tài khoản" CssClass="btn btn-fpt btn-sm px-4 fw-bold" OnClick="btnSaveUser_Click" />
            <asp:Button ID="btnCancelForm" runat="server" Text="Hủy" CssClass="btn btn-secondary btn-sm" OnClick="btnCancelPanels_Click" CausesValidation="false" />
        </div>
    </asp:Panel>

    <!-- RESET PASSWORD (Manager) -->
    <asp:Panel ID="pnlPwd" runat="server" Visible="false" CssClass="card card-custom p-3 mb-4 border-start border-4 border-warning">
        <asp:HiddenField ID="hfPwdId" runat="server" />
        <h5 class="fw-bold text-navy mb-3"><i class="fa-solid fa-key me-2"></i>Đặt lại mật khẩu: <asp:Literal ID="litPwdTarget" runat="server"></asp:Literal></h5>
        <div class="row g-2 align-items-end">
            <div class="col-md-4">
                <label class="form-label fw-semibold small">Mật khẩu mới (tối thiểu 6 ký tự):</label>
                <asp:TextBox ID="txtResetPwd" runat="server" CssClass="form-control form-control-sm" MaxLength="72" Text="123456"></asp:TextBox>
            </div>
            <div class="col-md-4 d-flex gap-2">
                <asp:Button ID="btnDoReset" runat="server" Text="Đặt lại mật khẩu" CssClass="btn btn-warning btn-sm fw-semibold" OnClick="btnDoReset_Click" />
                <asp:Button ID="btnCancelPwd" runat="server" Text="Hủy" CssClass="btn btn-secondary btn-sm" OnClick="btnCancelPanels_Click" CausesValidation="false" />
            </div>
        </div>
    </asp:Panel>

    <!-- PARENT LINKS (Manager) -->
    <asp:Panel ID="pnlLinks" runat="server" Visible="false" CssClass="card card-custom p-3 mb-4 border-start border-4 border-info">
        <asp:HiddenField ID="hfLinkId" runat="server" />
        <h5 class="fw-bold text-navy mb-3"><i class="fa-solid fa-people-roof me-2"></i><asp:Literal ID="litLinkTitle" runat="server"></asp:Literal></h5>
        <asp:GridView ID="gvLinks" runat="server" AutoGenerateColumns="False" CssClass="table table-sm align-middle mb-3" GridLines="None" OnRowCommand="gvLinks_RowCommand">
            <Columns>
                <asp:BoundField DataField="Name" HeaderText="Họ và tên" />
                <asp:BoundField DataField="ClassName" HeaderText="Lớp" />
                <asp:BoundField DataField="Phone" HeaderText="Số điện thoại" />
                <asp:BoundField DataField="Email" HeaderText="Email" />
                <asp:TemplateField>
                    <ItemTemplate>
                        <asp:LinkButton runat="server" CommandName="unlink" CommandArgument='<%# Eval("Id") %>' CssClass="btn btn-sm btn-outline-danger"
                            OnClientClick="return confirm('Gỡ liên kết này?');"><i class="fa-solid fa-link-slash me-1"></i>Gỡ liên kết</asp:LinkButton>
                    </ItemTemplate>
                </asp:TemplateField>
            </Columns>
            <EmptyDataTemplate><div class="text-muted small">Chưa có liên kết nào.</div></EmptyDataTemplate>
        </asp:GridView>
        <div class="row g-2 align-items-end">
            <div class="col-md-5">
                <label class="form-label fw-semibold small"><asp:Literal ID="litLinkHint" runat="server"></asp:Literal></label>
                <asp:TextBox ID="txtLinkWho" runat="server" CssClass="form-control form-control-sm" MaxLength="150" placeholder="Số điện thoại hoặc email"></asp:TextBox>
            </div>
            <div class="col-md-4 d-flex gap-2">
                <asp:Button ID="btnAddLink" runat="server" Text="Thêm liên kết" CssClass="btn btn-info btn-sm fw-semibold" OnClick="btnAddLink_Click" />
                <asp:Button ID="btnCloseLinks" runat="server" Text="Đóng" CssClass="btn btn-secondary btn-sm" OnClick="btnCancelPanels_Click" CausesValidation="false" />
            </div>
        </div>
    </asp:Panel>

    <!-- FILTERS -->
    <div class="card card-custom p-3 mb-4">
        <div class="row g-2 align-items-end">
            <div class="col-md-3 col-sm-6">
                <label class="form-label small fw-semibold"><i class="fa-solid fa-user-tag text-muted me-1"></i>Lọc theo vai trò:</label>
                <asp:DropDownList ID="ddlRole" runat="server" CssClass="form-select form-select-sm" AutoPostBack="true" OnSelectedIndexChanged="FilterChanged">
                    <asp:ListItem Value="ALL" Text="Tất cả vai trò"></asp:ListItem>
                    <asp:ListItem Value="HS" Text="Học sinh (HS)"></asp:ListItem>
                    <asp:ListItem Value="GV" Text="Giáo viên (GV)"></asp:ListItem>
                    <asp:ListItem Value="PH" Text="Phụ huynh (PH)"></asp:ListItem>
                    <asp:ListItem Value="Manager" Text="Quản lý (Manager)"></asp:ListItem>
                </asp:DropDownList>
            </div>
            <div class="col-md-3 col-sm-6">
                <label class="form-label small fw-semibold"><i class="fa-solid fa-school text-muted me-1"></i>Lọc theo lớp học:</label>
                <asp:DropDownList ID="ddlClass" runat="server" CssClass="form-select form-select-sm" AutoPostBack="true" OnSelectedIndexChanged="FilterChanged">
                </asp:DropDownList>
            </div>
            <div class="col-md-4 col-sm-8">
                <label class="form-label small fw-semibold"><i class="fa-solid fa-magnifying-glass text-muted me-1"></i>Tìm kiếm tài khoản:</label>
                <asp:TextBox ID="txtSearch" runat="server" CssClass="form-control form-control-sm" placeholder="Họ tên, Email, Số điện thoại..."></asp:TextBox>
            </div>
            <div class="col-md-2 col-sm-4 d-flex gap-2">
                <asp:Button ID="btnSearch" runat="server" Text="Tìm" CssClass="btn btn-sm btn-primary w-50" OnClick="btnSearch_Click" />
                <asp:Button ID="btnResetFilter" runat="server" Text="Làm mới" CssClass="btn btn-sm btn-outline-secondary w-50" OnClick="btnResetFilter_Click" />
            </div>
        </div>
    </div>

    <!-- LIST -->
    <div class="card card-custom">
        <div class="card-header-fpt">
            <span>
                <i class="fa-solid fa-address-book me-2 text-primary"></i>Danh Sách Hồ Sơ Người Dùng
                <span class="badge bg-secondary ms-2"><asp:Literal ID="litStudentCount" runat="server">0</asp:Literal> tài khoản</span>
            </span>
        </div>
        <div class="table-responsive">
            <asp:GridView ID="gvStudents" runat="server" AutoGenerateColumns="False" DataKeyNames="Id"
                CssClass="table table-hover table-custom align-middle mb-0" GridLines="None" OnRowCommand="gvStudents_RowCommand">
                <Columns>
                    <asp:TemplateField HeaderText="Vai Trò" HeaderStyle-CssClass="text-center" ItemStyle-CssClass="text-center">
                        <ItemTemplate><%# GetRoleBadge(Convert.ToString(Eval("Role"))) %></ItemTemplate>
                    </asp:TemplateField>
                    <asp:BoundField DataField="Id" HeaderText="Mã" HeaderStyle-CssClass="text-center" ItemStyle-CssClass="text-center fw-bold text-dark font-monospace" />
                    <asp:BoundField DataField="Name" HeaderText="Họ và Tên" ItemStyle-CssClass="fw-semibold text-dark" />
                    <asp:BoundField DataField="ClassName" HeaderText="Lớp" HeaderStyle-CssClass="text-center" ItemStyle-CssClass="text-center fw-bold text-primary" />
                    <asp:BoundField DataField="Phone" HeaderText="Số Điện Thoại" HeaderStyle-CssClass="text-center" ItemStyle-CssClass="text-center font-monospace fw-semibold" />
                    <asp:BoundField DataField="Email" HeaderText="Email" />
                    <asp:TemplateField HeaderText="Phụ huynh / Con">
                        <ItemTemplate><%# GetRelatives(Convert.ToInt32(Eval("Id")), Convert.ToString(Eval("Role"))) %></ItemTemplate>
                    </asp:TemplateField>
                    <asp:TemplateField HeaderText="Hành Động" HeaderStyle-CssClass="text-center" ItemStyle-CssClass="text-center text-nowrap">
                        <ItemTemplate>
                            <%# GetViewButtons(Convert.ToString(Eval("Role")), Convert.ToString(Eval("ClassName")), Convert.ToInt32(Eval("Id"))) %>
                            <asp:LinkButton runat="server" Visible='<%# IsManagerView %>' CommandName="edituser" CommandArgument='<%# Eval("Id") %>' CssClass="btn btn-sm btn-outline-primary" ToolTip="Sửa"><i class="fa-solid fa-pen"></i></asp:LinkButton>
                            <asp:LinkButton runat="server" Visible='<%# IsManagerView %>' CommandName="pwd" CommandArgument='<%# Eval("Id") %>' CssClass="btn btn-sm btn-outline-warning" ToolTip="Đặt lại mật khẩu"><i class="fa-solid fa-key"></i></asp:LinkButton>
                            <asp:LinkButton runat="server" Visible='<%# IsManagerView && CanLink(Convert.ToString(Eval("Role"))) %>' CommandName="links" CommandArgument='<%# Eval("Id") %>' CssClass="btn btn-sm btn-outline-info" ToolTip="Liên kết phụ huynh / con"><i class="fa-solid fa-people-roof"></i></asp:LinkButton>
                            <asp:LinkButton runat="server" Visible='<%# IsManagerView %>' CommandName="deluser" CommandArgument='<%# Eval("Id") %>' CssClass="btn btn-sm btn-outline-danger" ToolTip="Xóa"
                                OnClientClick="return confirm('Xóa tài khoản này? Thao tác không thể hoàn tác.');"><i class="fa-solid fa-trash"></i></asp:LinkButton>
                        </ItemTemplate>
                    </asp:TemplateField>
                </Columns>
                <EmptyDataTemplate>
                    <div class="text-center py-5">
                        <i class="fa-solid fa-user-slash fa-3x text-muted mb-3"></i>
                        <h6 class="text-muted">Không tìm thấy tài khoản nào phù hợp với bộ lọc hiện tại.</h6>
                    </div>
                </EmptyDataTemplate>
            </asp:GridView>
        </div>
    </div>
</asp:Content>
