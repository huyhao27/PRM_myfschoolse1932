<%@ Page Title="Chi Tiết Câu Lạc Bộ" Language="C#" MasterPageFile="~/Site.Master" AutoEventWireup="true" CodeBehind="ViewClub.aspx.cs" Inherits="MyfschoolWeb.ViewClub" ResponseEncoding="utf-8" ContentType="text/html; charset=utf-8" %>

<asp:Content ID="BodyContent" ContentPlaceHolderID="MainContent" runat="server">
    <div class="d-flex justify-content-between align-items-center mb-4 flex-wrap gap-2">
        <h3 class="fw-bold text-navy mb-0"><i class="fa-solid fa-people-group text-success me-2"></i><asp:Literal ID="litTitle" runat="server">Câu Lạc Bộ</asp:Literal></h3>
        <a href="ListClub.aspx" class="btn btn-outline-secondary"><i class="fa-solid fa-arrow-left me-1"></i> Danh sách CLB</a>
    </div>

    <asp:Panel ID="pnlMsg" runat="server" Visible="false" CssClass="alert alert-info">
        <asp:Literal ID="litMsg" runat="server"></asp:Literal>
    </asp:Panel>

    <asp:Panel ID="pnlNotFound" runat="server" Visible="false" CssClass="card card-custom text-center py-5">
        <i class="fa-solid fa-circle-question fa-3x text-muted mb-3"></i>
        <h6 class="text-muted">Không tìm thấy câu lạc bộ này.</h6>
        <div><a href="ListClub.aspx" class="btn btn-fpt btn-sm mt-2">Về danh sách câu lạc bộ</a></div>
    </asp:Panel>

    <asp:Panel ID="pnlInfo" runat="server" Visible="false" CssClass="card card-custom mb-4">
        <div class="card-header-fpt">
            <span><asp:Literal ID="litIcon" runat="server"></asp:Literal> <asp:Literal ID="litName" runat="server"></asp:Literal></span>
            <span class="badge bg-primary"><asp:Literal ID="litMembers" runat="server">0</asp:Literal> thành viên</span>
        </div>
        <div class="card-body">
            <div class="row g-3">
                <div class="col-12">
                    <div class="text-muted small">Mô tả</div>
                    <div style="white-space: pre-wrap;"><asp:Literal ID="litDescription" runat="server"></asp:Literal></div>
                </div>
                <div class="col-md-6"><div class="text-muted small">Lịch sinh hoạt</div><div class="fw-semibold"><asp:Literal ID="litMeeting" runat="server"></asp:Literal></div></div>
                <div class="col-md-6"><div class="text-muted small">Địa điểm</div><div class="fw-semibold"><asp:Literal ID="litLocation" runat="server"></asp:Literal></div></div>
                <div class="col-md-6"><div class="text-muted small">Giáo viên phụ trách</div><div class="fw-semibold"><asp:Literal ID="litAdvisor" runat="server"></asp:Literal></div></div>
                <div class="col-md-6"><div class="text-muted small">Chủ nhiệm CLB</div><div class="fw-semibold"><asp:Literal ID="litPresident" runat="server"></asp:Literal></div></div>
                <div class="col-md-6"><div class="text-muted small">Thành viên gốc / đã duyệt</div><div class="fw-semibold"><asp:Literal ID="litBreakdown" runat="server"></asp:Literal></div></div>
            </div>
        </div>
    </asp:Panel>

    <asp:Panel ID="pnlEdit" runat="server" Visible="false" CssClass="card card-custom mb-4">
        <div class="card-header-fpt"><span><i class="fa-solid fa-pen-to-square me-2"></i><asp:Literal ID="litEditTitle" runat="server">Chỉnh sửa thông tin CLB (Quản lý)</asp:Literal></span></div>
        <div class="card-body">
            <div class="row g-3">
                <div class="col-md-8">
                    <label class="form-label fw-semibold small">Tên CLB *</label>
                    <asp:TextBox ID="txtName" runat="server" CssClass="form-control" MaxLength="100"></asp:TextBox>
                </div>
                <div class="col-md-4">
                    <label class="form-label fw-semibold small">Biểu tượng (tối đa 10 ký tự)</label>
                    <asp:TextBox ID="txtIcon" runat="server" CssClass="form-control" MaxLength="10"></asp:TextBox>
                </div>
                <div class="col-12">
                    <label class="form-label fw-semibold small">Mô tả (tối đa 500 ký tự)</label>
                    <asp:TextBox ID="txtDescription" runat="server" TextMode="MultiLine" Rows="3" CssClass="form-control" MaxLength="500"></asp:TextBox>
                </div>
                <div class="col-md-6">
                    <label class="form-label fw-semibold small">Lịch sinh hoạt</label>
                    <asp:TextBox ID="txtMeeting" runat="server" CssClass="form-control" MaxLength="100"></asp:TextBox>
                </div>
                <div class="col-md-6">
                    <label class="form-label fw-semibold small">Địa điểm</label>
                    <asp:TextBox ID="txtLocation" runat="server" CssClass="form-control" MaxLength="100"></asp:TextBox>
                </div>
                <div class="col-md-4">
                    <label class="form-label fw-semibold small">Giáo viên phụ trách</label>
                    <asp:TextBox ID="txtAdvisor" runat="server" CssClass="form-control" MaxLength="100"></asp:TextBox>
                </div>
                <div class="col-md-4">
                    <label class="form-label fw-semibold small">Chủ nhiệm CLB</label>
                    <asp:TextBox ID="txtPresident" runat="server" CssClass="form-control" MaxLength="100"></asp:TextBox>
                </div>
                <div class="col-md-4">
                    <label class="form-label fw-semibold small">Số thành viên gốc</label>
                    <asp:TextBox ID="txtBase" runat="server" CssClass="form-control" MaxLength="6" Text="0"></asp:TextBox>
                </div>
            </div>
            <div class="mt-3">
                <asp:LinkButton ID="btnSave" runat="server" CssClass="btn btn-fpt" OnClick="btnSave_Click"><i class="fa-solid fa-floppy-disk me-1"></i> <asp:Literal ID="litSaveText" runat="server">Lưu thay đổi</asp:Literal></asp:LinkButton>
            </div>
        </div>
    </asp:Panel>

    <asp:Panel ID="pnlMembers" runat="server" Visible="false" CssClass="card card-custom">
        <div class="card-header-fpt"><span><i class="fa-solid fa-users me-2"></i>Thành viên đăng ký qua ứng dụng</span></div>
        <asp:Panel ID="pnlNoMembers" runat="server" Visible="false" CssClass="text-center py-4 text-muted">Chưa có học sinh nào đăng ký tham gia.</asp:Panel>
        <div class="table-responsive">
            <table class="table table-hover table-custom align-middle mb-0">
                <thead>
                    <tr>
                        <th>Họ và tên</th>
                        <th class="text-center">Lớp</th>
                        <th>Ngày đăng ký</th>
                        <th class="text-center">Trạng thái</th>
                        <th class="text-center">Thao tác</th>
                    </tr>
                </thead>
                <tbody>
                    <asp:Repeater ID="rptMembers" runat="server" OnItemCommand="rptMembers_ItemCommand">
                        <ItemTemplate>
                            <tr>
                                <td class="fw-semibold text-dark"><%# Server.HtmlEncode((string)Eval("Name")) %></td>
                                <td class="text-center fw-bold text-primary"><%# Server.HtmlEncode((string)Eval("ClassName") ?? "") %></td>
                                <td class="small"><%# Stamp(Eval("JoinedAt")) %></td>
                                <td class="text-center"><%# StatusBadge(Eval("Status")) %></td>
                                <td class="text-center">
                                    <asp:LinkButton runat="server" CommandName="approve" CommandArgument='<%# Eval("UserId") %>' Visible='<%# (string)Eval("Status") == "pending" %>' CssClass="btn btn-sm btn-success me-1"><i class="fa-solid fa-check me-1"></i> Duyệt</asp:LinkButton>
                                    <asp:LinkButton runat="server" CommandName="reject" CommandArgument='<%# Eval("UserId") %>' Visible='<%# (string)Eval("Status") == "pending" %>' CssClass="btn btn-sm btn-danger"><i class="fa-solid fa-xmark me-1"></i> Từ chối</asp:LinkButton>
                                </td>
                            </tr>
                        </ItemTemplate>
                    </asp:Repeater>
                </tbody>
            </table>
        </div>
    </asp:Panel>
</asp:Content>
