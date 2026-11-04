<%@ Page Language="C#" AutoEventWireup="true" CodeBehind="Login.aspx.cs" Inherits="MyfschoolWeb.Login" ResponseEncoding="utf-8" ContentType="text/html; charset=utf-8" %>
<!DOCTYPE html>
<html lang="vi">
<head runat="server">
    <meta charset="utf-8" />
    <meta name="viewport" content="width=device-width, initial-scale=1.0" />
    <title>Đăng nhập - MyFSchool</title>
    <link href="https://cdn.jsdelivr.net/npm/bootstrap@5.3.3/dist/css/bootstrap.min.css" rel="stylesheet" />
    <link href="https://cdnjs.cloudflare.com/ajax/libs/font-awesome/6.5.1/css/all.min.css" rel="stylesheet" />
    <link rel="preconnect" href="https://fonts.googleapis.com">
    <link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
    <link href="https://fonts.googleapis.com/css2?family=Be+Vietnam+Pro:ital,wght@0,400;0,500;0,600;0,700&display=swap" rel="stylesheet">
    <link href="Content/site.css" rel="stylesheet" />
</head>
<body class="auth-page">
    <a class="skip-link" href="#login-form-panel">Bỏ qua, đến biểu mẫu đăng nhập</a>
    <div class="auth-layout">
        <section class="auth-brand" aria-label="Giới thiệu MyFSchool">
            <span class="auth-logo"><img src="Content/fpt-logo.svg" alt="FPT Education" /></span>
            <span class="auth-brand-mobile-title">MyFSchool</span>
            <div class="auth-pitch">
                <h1>MyFSchool<br />Cổng quản lý trường học</h1>
                <p>Nhập điểm, xếp thời khóa biểu, duyệt đơn từ và theo dõi câu lạc bộ của toàn trường tại một nơi, nhanh và chính xác.</p>
                <ul class="auth-points">
                    <li><i class="fa-solid fa-book-bookmark" aria-hidden="true"></i><span>Sổ điểm điện tử theo Thông tư 22</span></li>
                    <li><i class="fa-solid fa-envelope-circle-check" aria-hidden="true"></i><span>Duyệt đơn từ của học sinh ngay trên máy</span></li>
                    <li><i class="fa-solid fa-calendar-days" aria-hidden="true"></i><span>Thời khóa biểu và câu lạc bộ luôn cập nhật</span></li>
                </ul>
            </div>
            <div class="auth-brand-foot">Trường THPT FPT Hà Nội</div>
        </section>

        <main class="auth-panel" id="login-form-panel">
            <form id="form1" runat="server" class="auth-card" novalidate="novalidate">
                <h2>Đăng nhập</h2>
                <p class="page-desc">Dành cho tài khoản Quản lý và Giáo viên.</p>

                <asp:Panel ID="pnlAlert" runat="server" Visible="false" CssClass="alert-inline is-error" role="alert" data-autofocus-alert="1">
                    <asp:Literal ID="litAlert" runat="server"></asp:Literal>
                </asp:Panel>

                <div class="form-field">
                    <label for="txtIdentifier">Số điện thoại <span class="req" aria-hidden="true">*</span></label>
                    <asp:TextBox ID="txtIdentifier" runat="server" CssClass="form-control" TextMode="Phone" placeholder="Ví dụ: 0901000002" autocomplete="username" inputmode="tel" aria-describedby="phoneHelp" required="required"></asp:TextBox>
                    <span class="form-help" id="phoneHelp">Số điện thoại đã đăng ký với nhà trường.</span>
                </div>

                <div class="form-field">
                    <label for="txtPassword">Mật khẩu <span class="req" aria-hidden="true">*</span></label>
                    <div class="input-affix">
                        <asp:TextBox ID="txtPassword" runat="server" CssClass="form-control" TextMode="Password" autocomplete="current-password" required="required"></asp:TextBox>
                        <button type="button" class="icon-btn" data-toggle-password="txtPassword" aria-pressed="false" aria-label="Hiện mật khẩu" title="Hiện mật khẩu"><i class="fa-solid fa-eye" aria-hidden="true"></i></button>
                    </div>
                </div>

                <div class="btn-wrap">
                    <asp:Button ID="btnLogin" runat="server" Text="Đăng nhập" CssClass="btn-brand" OnClick="btnLogin_Click" data-loading-text="Đang đăng nhập..." />
                    <span class="btn-spinner" aria-hidden="true"></span>
                </div>
                <p class="auth-note"><i class="fa-solid fa-lock me-1" aria-hidden="true"></i>Chỉ tài khoản <strong>Quản lý</strong> và <strong>Giáo viên</strong> được truy cập cổng này.</p>
            </form>
        </main>
    </div>
    <script src="Content/site.js"></script>
</body>
</html>
