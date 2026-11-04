<%@ Page Title="Thời Khóa Biểu" Language="C#" MasterPageFile="~/Site.Master" AutoEventWireup="true" CodeBehind="ListSchedule.aspx.cs" Inherits="MyfschoolWeb.ListSchedule" ResponseEncoding="utf-8" ContentType="text/html; charset=utf-8" %>

<asp:Content ID="BodyContent" ContentPlaceHolderID="MainContent" runat="server">
    <div class="d-flex justify-content-between align-items-center mb-4 flex-wrap gap-2">
        <div>
            <h3 class="fw-bold text-navy mb-1"><i class="fa-solid fa-calendar-days text-success me-2"></i>Thời Khóa Biểu & Lịch Học Tuần</h3>
            <p class="text-muted mb-0"><asp:Literal ID="litSubtitle" runat="server"></asp:Literal></p>
        </div>
        <div class="d-flex gap-2">
            <asp:PlaceHolder ID="phManagerActions" runat="server">
                <asp:LinkButton ID="btnShowAdd" runat="server" CssClass="btn btn-success fw-semibold" OnClick="btnShowAdd_Click" CausesValidation="false"><i class="fa-solid fa-plus me-1"></i> Thêm tiết học</asp:LinkButton>
                <a href="ImportData.aspx" class="btn btn-fpt"><i class="fa-solid fa-file-import me-1"></i> Import Lịch Học</a>
            </asp:PlaceHolder>
        </div>
    </div>

    <asp:Panel ID="pnlStatusAlert" runat="server" Visible="false" CssClass="alert alert-dismissible fade show mb-4 shadow-sm" role="alert">
        <asp:Literal ID="litStatusMessage" runat="server"></asp:Literal>
        <button type="button" class="btn-close" data-bs-dismiss="alert" aria-label="Close"></button>
    </asp:Panel>

    <!-- FORM: ADD / EDIT LESSON (Manager) -->
    <asp:Panel ID="pnlForm" runat="server" Visible="false" CssClass="card card-custom p-3 mb-4 border-start border-4 border-success">
        <asp:HiddenField ID="hfId" runat="server" />
        <h5 class="fw-bold text-navy mb-3"><asp:Literal ID="litFormTitle" runat="server"></asp:Literal></h5>
        <div class="row g-3">
            <div class="col-md-2">
                <label class="form-label fw-semibold small">Lớp (*):</label>
                <asp:TextBox ID="txtClass" runat="server" CssClass="form-control form-control-sm" MaxLength="20" placeholder="10A1"></asp:TextBox>
            </div>
            <div class="col-md-2">
                <label class="form-label fw-semibold small">Thứ (*):</label>
                <asp:DropDownList ID="ddlFormDay" runat="server" CssClass="form-select form-select-sm"></asp:DropDownList>
            </div>
            <div class="col-md-3">
                <label class="form-label fw-semibold small">Tiết (*):</label>
                <asp:DropDownList ID="ddlFormPeriod" runat="server" CssClass="form-select form-select-sm"></asp:DropDownList>
            </div>
            <div class="col-md-3">
                <label class="form-label fw-semibold small">Môn học (*):</label>
                <asp:TextBox ID="txtSubject" runat="server" CssClass="form-control form-control-sm" MaxLength="100" placeholder="Toán"></asp:TextBox>
            </div>
            <div class="col-md-2">
                <label class="form-label fw-semibold small">Phòng:</label>
                <asp:TextBox ID="txtRoom" runat="server" CssClass="form-control form-control-sm" MaxLength="30" placeholder="P.301"></asp:TextBox>
            </div>
            <div class="col-md-4">
                <label class="form-label fw-semibold small">Giáo viên (*):</label>
                <asp:DropDownList ID="ddlFormTeacher" runat="server" CssClass="form-select form-select-sm"></asp:DropDownList>
            </div>
            <div class="col-md-2">
                <label class="form-label fw-semibold small">Hình thức:</label>
                <asp:TextBox ID="txtMode" runat="server" CssClass="form-control form-control-sm" MaxLength="30" placeholder="Trực tiếp"></asp:TextBox>
            </div>
            <div class="col-md-6">
                <label class="form-label fw-semibold small">Nội dung bài học:</label>
                <asp:TextBox ID="txtContent" runat="server" CssClass="form-control form-control-sm" MaxLength="200"></asp:TextBox>
            </div>
            <div class="col-md-6">
                <label class="form-label fw-semibold small">Chuẩn bị:</label>
                <asp:TextBox ID="txtPrep" runat="server" CssClass="form-control form-control-sm" MaxLength="200"></asp:TextBox>
            </div>
            <div class="col-md-6">
                <label class="form-label fw-semibold small">Ghi chú:</label>
                <asp:TextBox ID="txtNote" runat="server" CssClass="form-control form-control-sm" MaxLength="300"></asp:TextBox>
            </div>
        </div>
        <div class="form-text small mb-3">Giờ học tự động theo tiết: 1 (07:30-08:15), 2 (08:25-09:10), 3 (09:20-10:05), 4 (10:15-11:00), 5 (11:10-11:55), 6-8 buổi chiều.</div>
        <div class="d-flex gap-2">
            <asp:Button ID="btnSave" runat="server" Text="Lưu tiết học" CssClass="btn btn-fpt btn-sm px-4 fw-bold" OnClick="btnSave_Click" />
            <asp:Button ID="btnCancel" runat="server" Text="Hủy" CssClass="btn btn-secondary btn-sm" OnClick="btnCancel_Click" CausesValidation="false" />
        </div>
    </asp:Panel>

    <!-- FILTERS -->
    <div class="card card-custom p-3 mb-4">
        <div class="row g-2 align-items-end">
            <div class="col-md-4 col-sm-6">
                <label class="form-label small fw-semibold">Lớp học:</label>
                <asp:DropDownList ID="ddlClass" runat="server" CssClass="form-select form-select-sm" AutoPostBack="true" OnSelectedIndexChanged="FilterChanged">
                </asp:DropDownList>
            </div>
            <div class="col-md-4 col-sm-6">
                <label class="form-label small fw-semibold">Thứ trong tuần (danh sách bên dưới):</label>
                <asp:DropDownList ID="ddlDay" runat="server" CssClass="form-select form-select-sm" AutoPostBack="true" OnSelectedIndexChanged="FilterChanged">
                </asp:DropDownList>
            </div>
            <div class="col-md-4 col-sm-12 d-flex align-items-end justify-content-end">
                <span class="badge bg-light text-dark border p-2"><i class="fa-solid fa-clock me-1"></i> Sáng 07:30 - 11:55 (5 tiết) / Chiều từ 13:30</span>
            </div>
        </div>
    </div>

    <!-- WEEKLY GRID -->
    <asp:Panel ID="pnlWeek" runat="server" CssClass="card card-custom mb-4">
        <div class="card-header-fpt"><span><i class="fa-solid fa-table-cells me-2"></i>Thời khóa biểu tuần - <asp:Literal ID="litWeekClass" runat="server"></asp:Literal></span></div>
        <div class="table-responsive p-2">
            <asp:Literal ID="litWeek" runat="server"></asp:Literal>
        </div>
    </asp:Panel>

    <!-- LIST -->
    <div class="card card-custom">
        <div class="card-header-fpt">
            <span>
                <i class="fa-solid fa-list-check me-2"></i>Lịch Giảng Dạy & Học Tập
                <span class="badge bg-secondary ms-2"><asp:Literal ID="litScheduleCount" runat="server">0</asp:Literal> tiết học</span>
            </span>
        </div>
        <div class="table-responsive">
            <asp:GridView ID="gvSchedules" runat="server" AutoGenerateColumns="False" DataKeyNames="Id"
                CssClass="table table-hover table-custom align-middle mb-0" GridLines="None" OnRowCommand="gvSchedules_RowCommand">
                <Columns>
                    <asp:BoundField DataField="ClassName" HeaderText="Lớp" HeaderStyle-CssClass="text-center" ItemStyle-CssClass="text-center fw-bold text-primary" />
                    <asp:BoundField DataField="DayName" HeaderText="Thứ" HeaderStyle-CssClass="text-center" ItemStyle-CssClass="text-center fw-bold" />
                    <asp:BoundField DataField="Period" HeaderText="Tiết" HeaderStyle-CssClass="text-center" ItemStyle-CssClass="text-center badge-slot" />
                    <asp:TemplateField HeaderText="Khung Giờ" HeaderStyle-CssClass="text-center" ItemStyle-CssClass="text-center font-monospace small">
                        <ItemTemplate><%# Eval("StartTime") %> - <%# Eval("EndTime") %></ItemTemplate>
                    </asp:TemplateField>
                    <asp:BoundField DataField="Subject" HeaderText="Môn Học" ItemStyle-CssClass="fw-semibold text-dark" />
                    <asp:BoundField DataField="TeacherName" HeaderText="Giáo Viên" />
                    <asp:BoundField DataField="Room" HeaderText="Phòng" HeaderStyle-CssClass="text-center" ItemStyle-CssClass="text-center fw-semibold text-danger" />
                    <asp:BoundField DataField="Mode" HeaderText="Hình thức" />
                    <asp:BoundField DataField="Content" HeaderText="Nội dung" />
                    <asp:BoundField DataField="Note" HeaderText="Ghi chú" />
                    <asp:TemplateField HeaderText="" ItemStyle-CssClass="text-nowrap text-center">
                        <ItemTemplate>
                            <asp:LinkButton runat="server" Visible='<%# IsManagerView %>' CommandName="editlesson" CommandArgument='<%# Eval("Id") %>' CssClass="btn btn-sm btn-outline-primary" ToolTip="Sửa"><i class="fa-solid fa-pen"></i></asp:LinkButton>
                            <asp:LinkButton runat="server" Visible='<%# IsManagerView %>' CommandName="dellesson" CommandArgument='<%# Eval("Id") %>' CssClass="btn btn-sm btn-outline-danger" ToolTip="Xóa"
                                OnClientClick="return confirm('Xóa tiết học này?');"><i class="fa-solid fa-trash"></i></asp:LinkButton>
                        </ItemTemplate>
                    </asp:TemplateField>
                </Columns>
                <EmptyDataTemplate>
                    <div class="text-center py-5">
                        <i class="fa-solid fa-calendar-xmark fa-3x text-muted mb-3"></i>
                        <h6 class="text-muted">Không có lịch học nào cho lớp và thứ đã chọn.</h6>
                    </div>
                </EmptyDataTemplate>
            </asp:GridView>
        </div>
    </div>
</asp:Content>
