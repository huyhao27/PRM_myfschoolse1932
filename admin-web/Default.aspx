<%@ Page Title="Tổng quan" Language="C#" MasterPageFile="~/Site.Master" AutoEventWireup="true" CodeBehind="Default.aspx.cs" Inherits="MyfschoolWeb.Default" ResponseEncoding="utf-8" ContentType="text/html; charset=utf-8" %>

<asp:Content ID="BodyContent" ContentPlaceHolderID="MainContent" runat="server">

    <!-- Page header: greeting + role badge + quick actions -->
    <div class="page-header">
        <div class="page-header-text">
            <h1>
                Xin chào, <%: GreetingName %>
                <asp:Panel ID="pnlAdminBanner" runat="server" Visible="false" CssClass="role-badge is-manager"><i class="fa-solid fa-shield-halved" aria-hidden="true"></i>Quản lý toàn trường</asp:Panel>
                <asp:Panel ID="pnlTeacherBanner" runat="server" Visible="false" CssClass="role-badge is-teacher"><i class="fa-solid fa-chalkboard-user" aria-hidden="true"></i>Giáo viên (<asp:Literal ID="litTeacherName" runat="server">Thầy/Cô</asp:Literal>)</asp:Panel>
            </h1>
            <p class="page-desc"><asp:Literal ID="litDashboardSubtitle" runat="server">Hệ sinh thái Quản trị Học tập & Sổ điểm Điện tử THPT FPT Hà Nội</asp:Literal></p>
        </div>
        <div class="page-actions">
            <a href="AddGrade.aspx" class="btn-brand"><i class="fa-solid fa-plus" aria-hidden="true"></i>Nhập điểm mới</a>
            <a href="ListRequest.aspx?status=pending" class="btn-brand-outline"><i class="fa-solid fa-envelope-circle-check" aria-hidden="true"></i>Duyệt đơn</a>
            <a href="ListSchedule.aspx" class="btn-brand-outline"><i class="fa-solid fa-calendar-days" aria-hidden="true"></i>Thời khóa biểu</a>
        </div>
    </div>

    <!-- KPI cards -->
    <section class="stat-grid" aria-label="Số liệu chính">
        <div class="stat-card">
            <span class="stat-icon is-brand" aria-hidden="true"><i class="fa-solid fa-user-graduate"></i></span>
            <div class="stat-body">
                <span class="stat-label"><asp:Literal ID="litStudentCardSubtitle" runat="server">Tổng học sinh</asp:Literal></span>
                <p class="stat-value"><asp:Literal ID="litTotalStudents" runat="server">0</asp:Literal></p>
            </div>
        </div>
        <div class="stat-card">
            <span class="stat-icon" aria-hidden="true"><i class="fa-solid fa-chalkboard-user"></i></span>
            <div class="stat-body">
                <span class="stat-label"><asp:Literal ID="litClassCardSubtitle" runat="server">Số lớp quản lý</asp:Literal></span>
                <p class="stat-value"><asp:Literal ID="litTotalClasses" runat="server">0</asp:Literal></p>
            </div>
        </div>
        <div class="stat-card">
            <span class="stat-icon is-success" aria-hidden="true"><i class="fa-solid fa-clipboard-check"></i></span>
            <div class="stat-body">
                <span class="stat-label">Đầu điểm đã nhập</span>
                <p class="stat-value"><asp:Literal ID="litTotalGrades" runat="server">0</asp:Literal></p>
            </div>
        </div>
        <a href="ListRequest.aspx?status=pending" class="stat-card">
            <span class="stat-icon is-warning" aria-hidden="true"><i class="fa-solid fa-envelope-open-text"></i></span>
            <div class="stat-body">
                <span class="stat-label">Đơn chờ duyệt</span>
                <h2 class="stat-value text-danger"><asp:Literal ID="litPendingRequests" runat="server">0</asp:Literal></h2>
                <span class="stat-meta">Đơn từ bạn có thể xử lý</span>
            </div>
        </a>
        <a href="ListClub.aspx" class="stat-card">
            <span class="stat-icon is-warning" aria-hidden="true"><i class="fa-solid fa-people-group"></i></span>
            <div class="stat-body">
                <span class="stat-label">Yêu cầu vào CLB chờ duyệt</span>
                <h2 class="stat-value text-secondary"><asp:Literal ID="litPendingClubs" runat="server">0</asp:Literal></h2>
                <span class="stat-meta">Học sinh xin tham gia CLB</span>
            </div>
        </a>
    </section>

    <div class="grid-2 mb-4">
        <!-- Left column: to-do + shortcuts -->
        <div class="grid-stack">
            <section class="card-panel" aria-labelledby="todoTitle">
                <div class="card-panel-header">
                    <h2 id="todoTitle"><i class="fa-solid fa-list-check" aria-hidden="true"></i>Việc cần làm</h2>
                </div>
                <% if (PendingRequestsCount + PendingClubsCount == 0) { %>
                <div class="empty-state">
                    <div class="empty-icon" aria-hidden="true"><i class="fa-solid fa-check"></i></div>
                    <p class="mb-0">Không có việc nào đang chờ</p>
                </div>
                <% } else { %>
                <ul class="todo-list">
                    <% if (PendingRequestsCount > 0) { %>
                    <li><a class="todo-item" href="ListRequest.aspx?status=pending">
                        <span class="status-badge is-pending"><i class="fa-solid fa-hourglass-half" aria-hidden="true"></i>Chờ duyệt</span>
                        <span class="todo-text"><%= PendingRequestsCount %> đơn từ cần xử lý<span class="todo-sub">Xin nghỉ học, xin phép và các đơn khác</span></span>
                        <i class="fa-solid fa-chevron-right" aria-hidden="true"></i>
                    </a></li>
                    <% } %>
                    <% if (PendingClubsCount > 0) { %>
                    <li><a class="todo-item" href="ListClub.aspx">
                        <span class="status-badge is-pending"><i class="fa-solid fa-hourglass-half" aria-hidden="true"></i>Chờ duyệt</span>
                        <span class="todo-text"><%= PendingClubsCount %> yêu cầu vào câu lạc bộ<span class="todo-sub">Học sinh xin tham gia</span></span>
                        <i class="fa-solid fa-chevron-right" aria-hidden="true"></i>
                    </a></li>
                    <% } %>
                </ul>
                <% } %>
            </section>

            <section class="card-panel" aria-labelledby="quickTitle">
                <div class="card-panel-header">
                    <h2 id="quickTitle"><i class="fa-solid fa-bolt" aria-hidden="true"></i>Lối tắt</h2>
                </div>
                <ul class="todo-list">
                    <li><a class="todo-item" href="ListStudent.aspx">
                        <span class="stat-icon is-brand" aria-hidden="true"><i class="fa-solid fa-users-gear"></i></span>
                        <span class="todo-text"><asp:Literal ID="litStudentQuickTitle" runat="server">Hồ sơ học sinh</asp:Literal><span class="todo-sub"><asp:Literal ID="litStudentQuickDesc" runat="server">Quản lý hồ sơ học sinh các lớp</asp:Literal></span></span>
                        <i class="fa-solid fa-chevron-right" aria-hidden="true"></i>
                    </a></li>
                    <li><a class="todo-item" href="ListGrade.aspx">
                        <span class="stat-icon is-success" aria-hidden="true"><i class="fa-solid fa-book-open-reader"></i></span>
                        <span class="todo-text">Tra cứu sổ điểm<span class="todo-sub">Xem, sửa bảng điểm theo lớp</span></span>
                        <i class="fa-solid fa-chevron-right" aria-hidden="true"></i>
                    </a></li>
                </ul>
            </section>
        </div>

        <!-- Right column: class performance -->
        <section class="card-panel" aria-labelledby="perfTitle">
            <div class="card-panel-header">
                <h2 id="perfTitle"><i class="fa-solid fa-chart-simple" aria-hidden="true"></i>Kết quả học lực (TT22)</h2>
                <span class="status-badge is-info"><i class="fa-solid fa-award" aria-hidden="true"></i>Đạt chuẩn: <asp:Literal ID="litPassingRate" runat="server">100%</asp:Literal></span>
            </div>
            <div class="card-panel-body">
                <p class="page-desc mb-3">Số môn (điểm trung bình theo học sinh và môn) ở từng mức đánh giá.</p>

                <div class="meter-row">
                    <div class="meter-label">
                        <span class="meter-name is-approved"><i class="fa-solid fa-circle-check" aria-hidden="true"></i>Tốt (&ge; 8.0)</span>
                        <span class="meter-value"><asp:Literal ID="litTotCount" runat="server">0</asp:Literal> môn (<asp:Literal ID="litTotPercent" runat="server">0</asp:Literal>%)</span>
                    </div>
                    <div class="meter-track" aria-hidden="true"><asp:Panel ID="pnlTotBar" runat="server" CssClass="meter-fill is-approved"></asp:Panel></div>
                </div>
                <div class="meter-row">
                    <div class="meter-label">
                        <span class="meter-name is-info"><i class="fa-solid fa-circle-info" aria-hidden="true"></i>Khá (6.5 - 7.9)</span>
                        <span class="meter-value"><asp:Literal ID="litKhaCount" runat="server">0</asp:Literal> môn (<asp:Literal ID="litKhaPercent" runat="server">0</asp:Literal>%)</span>
                    </div>
                    <div class="meter-track" aria-hidden="true"><asp:Panel ID="pnlKhaBar" runat="server" CssClass="meter-fill is-info"></asp:Panel></div>
                </div>
                <div class="meter-row">
                    <div class="meter-label">
                        <span class="meter-name is-pending"><i class="fa-solid fa-circle-half-stroke" aria-hidden="true"></i>Đạt (5.0 - 6.4)</span>
                        <span class="meter-value"><asp:Literal ID="litDatCount" runat="server">0</asp:Literal> môn (<asp:Literal ID="litDatPercent" runat="server">0</asp:Literal>%)</span>
                    </div>
                    <div class="meter-track" aria-hidden="true"><asp:Panel ID="pnlDatBar" runat="server" CssClass="meter-fill is-pending"></asp:Panel></div>
                </div>
                <div class="meter-row">
                    <div class="meter-label">
                        <span class="meter-name is-rejected"><i class="fa-solid fa-circle-xmark" aria-hidden="true"></i>Chưa đạt (&lt; 5.0)</span>
                        <span class="meter-value"><asp:Literal ID="litChuaDatCount" runat="server">0</asp:Literal> môn (<asp:Literal ID="litChuaDatPercent" runat="server">0</asp:Literal>%)</span>
                    </div>
                    <div class="meter-track" aria-hidden="true"><asp:Panel ID="pnlChuaDatBar" runat="server" CssClass="meter-fill is-rejected"></asp:Panel></div>
                </div>
            </div>
        </section>
    </div>

    <!-- Recent grade entries -->
    <section class="card-panel" aria-labelledby="recentTitle">
        <div class="card-panel-header">
            <h2 id="recentTitle"><i class="fa-solid fa-clock-rotate-left" aria-hidden="true"></i>Đầu điểm cập nhật gần đây</h2>
            <a href="ListGrade.aspx" class="btn-brand-outline btn-sm-brand">Xem tất cả<i class="fa-solid fa-arrow-right" aria-hidden="true"></i></a>
        </div>
        <div class="table-responsive-stack">
            <asp:GridView ID="gvRecentGrades" runat="server" AutoGenerateColumns="False" CssClass="data-table" GridLines="None" UseAccessibleHeader="true">
                <EmptyDataTemplate>
                    <div class="empty-state">
                        <div class="empty-icon" aria-hidden="true"><i class="fa-solid fa-clipboard-list"></i></div>
                        <h3 class="empty-title">Chưa có đầu điểm nào</h3>
                        <p>Các đầu điểm vừa nhập sẽ hiện ở đây.</p>
                        <a href="AddGrade.aspx" class="btn-brand"><i class="fa-solid fa-plus" aria-hidden="true"></i>Nhập điểm mới</a>
                    </div>
                </EmptyDataTemplate>
                <Columns>
                    <asp:BoundField DataField="ClassName" HeaderText="Lớp" />
                    <asp:BoundField DataField="StudentId" HeaderText="Mã HS" ItemStyle-CssClass="num" HeaderStyle-CssClass="num" />
                    <asp:BoundField DataField="StudentName" HeaderText="Họ và tên" />
                    <asp:BoundField DataField="SubjectName" HeaderText="Môn học" />
                    <asp:BoundField DataField="Tx1Score" HeaderText="TX 1" ItemStyle-CssClass="num" HeaderStyle-CssClass="num" />
                    <asp:BoundField DataField="GkScore" HeaderText="GK" ItemStyle-CssClass="num" HeaderStyle-CssClass="num" />
                    <asp:BoundField DataField="CkScore" HeaderText="CK" ItemStyle-CssClass="num" HeaderStyle-CssClass="num" />
                    <asp:BoundField DataField="DtbMhk" HeaderText="ĐTBmhk" ItemStyle-CssClass="num fw-bold" HeaderStyle-CssClass="num" />
                    <asp:TemplateField HeaderText="Xếp loại">
                        <ItemTemplate><%# LevelBadge(Eval("EvaluationLevel")) %></ItemTemplate>
                    </asp:TemplateField>
                    <asp:TemplateField HeaderText="Thao tác" ItemStyle-CssClass="actions" HeaderStyle-CssClass="num">
                        <ItemTemplate>
                            <a href='ViewGrade.aspx?id=<%# Eval("Id") %>' class="icon-btn" title="Xem chi tiết" aria-label="Xem chi tiết đầu điểm"><i class="fa-solid fa-eye" aria-hidden="true"></i></a>
                            <a href='EditGrade.aspx?id=<%# Eval("Id") %>' class="icon-btn" title="Chỉnh sửa" aria-label="Chỉnh sửa đầu điểm"><i class="fa-solid fa-pen-to-square" aria-hidden="true"></i></a>
                        </ItemTemplate>
                    </asp:TemplateField>
                </Columns>
            </asp:GridView>
        </div>
    </section>
</asp:Content>
