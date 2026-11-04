<%@ Page Title="Đơn Từ" Language="C#" MasterPageFile="~/Site.Master" AutoEventWireup="true" CodeBehind="ListRequest.aspx.cs" Inherits="MyfschoolWeb.ListRequest" ResponseEncoding="utf-8" ContentType="text/html; charset=utf-8" %>

<asp:Content ID="BodyContent" ContentPlaceHolderID="MainContent" runat="server">
    <div class="d-flex justify-content-between align-items-center mb-4 flex-wrap gap-2">
        <div>
            <h3 class="fw-bold text-navy mb-1"><i class="fa-solid fa-envelope-open-text text-warning me-2"></i>Đơn Từ Của Học Sinh</h3>
            <p class="text-muted mb-0"><asp:Literal ID="litScope" runat="server"></asp:Literal></p>
        </div>
    </div>

    <div class="card card-custom p-3 mb-4">
        <div class="row g-2 align-items-end">
            <div class="col-md-3 col-sm-6">
                <label class="form-label small fw-semibold">Trạng thái:</label>
                <asp:DropDownList ID="ddlStatus" runat="server" CssClass="form-select form-select-sm" AutoPostBack="true" OnSelectedIndexChanged="FilterChanged">
                    <asp:ListItem Value="ALL">Tất cả trạng thái</asp:ListItem>
                    <asp:ListItem Value="pending">Chờ duyệt</asp:ListItem>
                    <asp:ListItem Value="approved">Đã duyệt</asp:ListItem>
                    <asp:ListItem Value="rejected">Từ chối</asp:ListItem>
                </asp:DropDownList>
            </div>
            <div class="col-md-3 col-sm-6">
                <label class="form-label small fw-semibold">Loại đơn:</label>
                <asp:DropDownList ID="ddlType" runat="server" CssClass="form-select form-select-sm" AutoPostBack="true" OnSelectedIndexChanged="FilterChanged">
                </asp:DropDownList>
            </div>
            <div class="col-md-4 col-sm-8">
                <label class="form-label small fw-semibold">Tìm học sinh (tên, lớp, mã):</label>
                <asp:TextBox ID="txtSearch" runat="server" CssClass="form-control form-control-sm" MaxLength="100" placeholder="Nhập từ khóa..."></asp:TextBox>
            </div>
            <div class="col-md-2 col-sm-4">
                <asp:LinkButton ID="btnSearch" runat="server" CssClass="btn btn-fpt btn-sm w-100" OnClick="FilterChanged"><i class="fa-solid fa-magnifying-glass me-1"></i> Tìm</asp:LinkButton>
            </div>
        </div>
    </div>

    <div class="card card-custom">
        <div class="card-header-fpt">
            <span>
                <i class="fa-solid fa-list me-2"></i>Danh sách đơn
                <span class="badge bg-secondary ms-2"><asp:Literal ID="litCount" runat="server">0</asp:Literal> đơn</span>
            </span>
        </div>
        <asp:Panel ID="pnlEmpty" runat="server" Visible="false" CssClass="text-center py-5">
            <i class="fa-solid fa-inbox fa-3x text-muted mb-3"></i>
            <h6 class="text-muted">Không có đơn nào phù hợp với bộ lọc.</h6>
        </asp:Panel>
        <div class="table-responsive">
            <table class="table table-hover table-custom align-middle mb-0">
                <thead>
                    <tr>
                        <th>Học sinh</th>
                        <th class="text-center">Lớp</th>
                        <th>Loại đơn</th>
                        <th>Thời gian xin</th>
                        <th>Người gửi</th>
                        <th>Ngày gửi</th>
                        <th class="text-center">Trạng thái</th>
                        <th class="text-center">Thao tác</th>
                    </tr>
                </thead>
                <tbody>
                    <asp:Repeater ID="rptRequests" runat="server">
                        <ItemTemplate>
                            <tr>
                                <td class="fw-semibold text-dark"><%# Server.HtmlEncode((string)Eval("StudentName")) %></td>
                                <td class="text-center fw-bold text-primary"><%# Server.HtmlEncode((string)Eval("ClassName") ?? "") %></td>
                                <td><%# Server.HtmlEncode((string)Eval("Type")) %></td>
                                <td class="small"><%# Period(Container.DataItem) %></td>
                                <td class="small"><%# Server.HtmlEncode((string)Eval("CreatorName")) %> <span class="text-muted">(<%# RoleText(Eval("CreatorRole")) %>)</span></td>
                                <td class="small"><%# Stamp(Eval("CreatedAt")) %></td>
                                <td class="text-center"><span class='<%# Badge(Eval("Status")) %>'><%# StatusText(Eval("Status")) %></span></td>
                                <td class="text-center">
                                    <a href='ViewRequest.aspx?id=<%# Eval("Id") %>' class="btn btn-sm btn-outline-info" title="Xem chi tiết"><i class="fa-solid fa-eye"></i></a>
                                </td>
                            </tr>
                        </ItemTemplate>
                    </asp:Repeater>
                </tbody>
            </table>
        </div>
    </div>
</asp:Content>
