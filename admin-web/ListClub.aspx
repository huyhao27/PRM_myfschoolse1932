<%@ Page Title="Câu Lạc Bộ" Language="C#" MasterPageFile="~/Site.Master" AutoEventWireup="true" CodeBehind="ListClub.aspx.cs" Inherits="MyfschoolWeb.ListClub" ResponseEncoding="utf-8" ContentType="text/html; charset=utf-8" %>

<asp:Content ID="BodyContent" ContentPlaceHolderID="MainContent" runat="server">
    <div class="d-flex justify-content-between align-items-center mb-4 flex-wrap gap-2">
        <div>
            <h3 class="fw-bold text-navy mb-1"><i class="fa-solid fa-people-group text-success me-2"></i>Câu Lạc Bộ</h3>
            <p class="text-muted mb-0">Danh sách câu lạc bộ, số thành viên và yêu cầu tham gia đang chờ duyệt.</p>
        </div>
        <asp:HyperLink ID="lnkNew" runat="server" NavigateUrl="ViewClub.aspx?new=1" CssClass="btn btn-fpt" Visible="false"><i class="fa-solid fa-plus-circle me-1"></i> Thêm CLB</asp:HyperLink>
    </div>

    <div class="card card-custom p-3 mb-4">
        <div class="row g-2 align-items-end">
            <div class="col-md-8 col-sm-8">
                <label class="form-label small fw-semibold">Tìm theo tên CLB:</label>
                <asp:TextBox ID="txtSearch" runat="server" CssClass="form-control form-control-sm" MaxLength="50" placeholder="Nhập tên câu lạc bộ..."></asp:TextBox>
            </div>
            <div class="col-md-4 col-sm-4">
                <asp:LinkButton ID="btnSearch" runat="server" CssClass="btn btn-fpt btn-sm w-100" OnClick="btnSearch_Click"><i class="fa-solid fa-magnifying-glass me-1"></i> Tìm</asp:LinkButton>
            </div>
        </div>
    </div>

    <div class="card card-custom">
        <div class="card-header-fpt">
            <span>
                <i class="fa-solid fa-list me-2"></i>Danh sách câu lạc bộ
                <span class="badge bg-secondary ms-2"><asp:Literal ID="litCount" runat="server">0</asp:Literal> CLB</span>
            </span>
        </div>
        <asp:Panel ID="pnlEmpty" runat="server" Visible="false" CssClass="text-center py-5">
            <i class="fa-solid fa-people-group fa-3x text-muted mb-3"></i>
            <h6 class="text-muted">Chưa có câu lạc bộ nào phù hợp.</h6>
        </asp:Panel>
        <div class="table-responsive">
            <table class="table table-hover table-custom align-middle mb-0">
                <thead>
                    <tr>
                        <th class="text-center">Biểu tượng</th>
                        <th>Tên CLB</th>
                        <th>Sinh hoạt</th>
                        <th>Phụ trách</th>
                        <th class="text-center">Thành viên</th>
                        <th class="text-center">Chờ duyệt</th>
                        <th class="text-center">Thao tác</th>
                    </tr>
                </thead>
                <tbody>
                    <asp:Repeater ID="rptClubs" runat="server">
                        <ItemTemplate>
                            <tr>
                                <td class="text-center fs-5"><%# Server.HtmlEncode((string)Eval("Icon") ?? "") %></td>
                                <td class="fw-semibold text-dark"><%# Server.HtmlEncode((string)Eval("Name")) %></td>
                                <td class="small"><%# Server.HtmlEncode((string)Eval("Meeting") ?? "") %></td>
                                <td class="small"><%# Server.HtmlEncode((string)Eval("Advisor") ?? "") %></td>
                                <td class="text-center fw-bold text-primary"><%# Eval("MemberCount") %></td>
                                <td class="text-center"><%# Pending(Eval("PendingMembers")) %></td>
                                <td class="text-center">
                                    <a href='ViewClub.aspx?id=<%# Eval("Id") %>' class="btn btn-sm btn-outline-info" title="Xem chi tiết"><i class="fa-solid fa-eye"></i></a>
                                </td>
                            </tr>
                        </ItemTemplate>
                    </asp:Repeater>
                </tbody>
            </table>
        </div>
    </div>
</asp:Content>
