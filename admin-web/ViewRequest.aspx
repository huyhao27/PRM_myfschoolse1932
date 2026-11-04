<%@ Page Title="Chi Tiết Đơn Từ" Language="C#" MasterPageFile="~/Site.Master" AutoEventWireup="true" CodeBehind="ViewRequest.aspx.cs" Inherits="MyfschoolWeb.ViewRequest" ResponseEncoding="utf-8" ContentType="text/html; charset=utf-8" %>

<asp:Content ID="BodyContent" ContentPlaceHolderID="MainContent" runat="server">
    <div class="d-flex justify-content-between align-items-center mb-4 flex-wrap gap-2">
        <h3 class="fw-bold text-navy mb-0"><i class="fa-solid fa-file-lines text-warning me-2"></i>Chi Tiết Đơn Từ</h3>
        <a href="ListRequest.aspx" class="btn btn-outline-secondary"><i class="fa-solid fa-arrow-left me-1"></i> Danh sách đơn</a>
    </div>

    <asp:Panel ID="pnlMsg" runat="server" Visible="false" CssClass="alert alert-info">
        <asp:Literal ID="litMsg" runat="server"></asp:Literal>
    </asp:Panel>

    <asp:Panel ID="pnlNotFound" runat="server" Visible="false" CssClass="card card-custom text-center py-5">
        <i class="fa-solid fa-circle-question fa-3x text-muted mb-3"></i>
        <h6 class="text-muted">Không tìm thấy đơn từ này hoặc bạn không có quyền xem.</h6>
        <div><a href="ListRequest.aspx" class="btn btn-fpt btn-sm mt-2">Về danh sách đơn từ</a></div>
    </asp:Panel>

    <asp:Panel ID="pnlDetail" runat="server" Visible="false">
        <div class="card card-custom mb-4">
            <div class="card-header-fpt">
                <span><i class="fa-solid fa-envelope-open-text me-2"></i><asp:Literal ID="litType" runat="server"></asp:Literal></span>
                <asp:Literal ID="litStatus" runat="server"></asp:Literal>
            </div>
            <div class="card-body">
                <div class="row g-3">
                    <div class="col-md-6">
                        <div class="text-muted small">Học sinh</div>
                        <div class="fw-semibold"><asp:Literal ID="litStudent" runat="server"></asp:Literal></div>
                    </div>
                    <div class="col-md-6">
                        <div class="text-muted small">Lớp</div>
                        <div class="fw-semibold text-primary"><asp:Literal ID="litClass" runat="server"></asp:Literal></div>
                    </div>
                    <div class="col-md-6">
                        <div class="text-muted small">Thời gian xin</div>
                        <div class="fw-semibold"><asp:Literal ID="litPeriod" runat="server"></asp:Literal></div>
                    </div>
                    <div class="col-md-6">
                        <div class="text-muted small">Người gửi / Ngày gửi</div>
                        <div class="fw-semibold"><asp:Literal ID="litCreator" runat="server"></asp:Literal></div>
                    </div>
                    <div class="col-12">
                        <div class="text-muted small">Lý do</div>
                        <div class="p-3 bg-light rounded-3" style="white-space: pre-wrap;"><asp:Literal ID="litReason" runat="server"></asp:Literal></div>
                    </div>
                </div>
            </div>
        </div>

        <asp:Panel ID="pnlHandled" runat="server" Visible="false" CssClass="card card-custom mb-4">
            <div class="card-header-fpt"><span><i class="fa-solid fa-user-check me-2"></i>Kết quả xử lý</span></div>
            <div class="card-body">
                <div class="row g-3">
                    <div class="col-md-6">
                        <div class="text-muted small">Người xử lý</div>
                        <div class="fw-semibold"><asp:Literal ID="litHandledBy" runat="server"></asp:Literal></div>
                    </div>
                    <div class="col-md-6">
                        <div class="text-muted small">Thời điểm xử lý</div>
                        <div class="fw-semibold"><asp:Literal ID="litHandledAt" runat="server"></asp:Literal></div>
                    </div>
                    <div class="col-12">
                        <div class="text-muted small">Nhận xét của giáo viên</div>
                        <div class="p-3 bg-light rounded-3" style="white-space: pre-wrap;"><asp:Literal ID="litComment" runat="server"></asp:Literal></div>
                    </div>
                </div>
            </div>
        </asp:Panel>

        <asp:Panel ID="pnlDecide" runat="server" Visible="false" CssClass="card card-custom mb-4">
            <div class="card-header-fpt"><span><i class="fa-solid fa-gavel me-2"></i>Xử lý đơn</span></div>
            <div class="card-body">
                <label class="form-label fw-semibold" for="<%= txtComment.ClientID %>">Nhận xét (tối đa 500 ký tự, không bắt buộc)</label>
                <asp:TextBox ID="txtComment" runat="server" TextMode="MultiLine" Rows="3" MaxLength="500" CssClass="form-control mb-3" placeholder="Ví dụ: Đồng ý. Em nhớ chép bài."></asp:TextBox>
                <div class="d-flex gap-2">
                    <asp:LinkButton ID="btnApprove" runat="server" CssClass="btn btn-success" OnClick="btnApprove_Click"><i class="fa-solid fa-check me-1"></i> Duyệt</asp:LinkButton>
                    <asp:LinkButton ID="btnReject" runat="server" CssClass="btn btn-danger" OnClick="btnReject_Click"><i class="fa-solid fa-xmark me-1"></i> Từ chối</asp:LinkButton>
                </div>
            </div>
        </asp:Panel>
    </asp:Panel>
</asp:Content>
