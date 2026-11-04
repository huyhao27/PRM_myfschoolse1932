<%@ Page Title="Trung Tâm Import Dữ Liệu" Language="C#" MasterPageFile="~/Site.Master" AutoEventWireup="true" CodeBehind="ImportData.aspx.cs" Inherits="MyfschoolWeb.ImportData" ResponseEncoding="utf-8" ContentType="text/html; charset=utf-8" %>

<asp:Content ID="BodyContent" ContentPlaceHolderID="MainContent" runat="server">
    <div class="d-flex justify-content-between align-items-center mb-4 flex-wrap gap-2">
        <div>
            <h3 class="fw-bold text-navy mb-1"><i class="fa-solid fa-cloud-arrow-up text-warning me-2"></i>Trung Tâm Import Dữ Liệu Hàng Loạt</h3>
            <p class="text-muted mb-0">Nhập tài khoản, thời khóa biểu và điểm số từ tệp CSV (UTF-8). Chỉ dành cho Quản lý.</p>
        </div>
        <div class="d-flex gap-2">
            <asp:Button ID="btnQuickSeed" runat="server" Text="Áp dụng dữ liệu mẫu còn thiếu" CssClass="btn btn-warning fw-semibold" OnClick="btnQuickSeed_Click"
                OnClientClick="return confirm('Chỉ thêm các dòng mẫu còn thiếu (lớp 10A1, liên kết phụ huynh, thời khóa biểu 10A1 khi đang trống). Không ghi đè dữ liệu. Tiếp tục?');" />
        </div>
    </div>

    <asp:Panel ID="pnlResult" runat="server" Visible="false" CssClass="card card-custom p-3 mb-4 border-start border-4 border-success">
        <div class="d-flex justify-content-between align-items-center flex-wrap gap-2">
            <div>
                <h5 class="fw-bold mb-1"><asp:Literal ID="litResultSummary" runat="server"></asp:Literal></h5>
                <div class="small text-muted"><asp:Literal ID="litResultStats" runat="server"></asp:Literal></div>
            </div>
            <div class="d-flex gap-2">
                <a href="ListStudent.aspx" class="btn btn-sm btn-outline-primary"><i class="fa-solid fa-users me-1"></i> Danh sách tài khoản</a>
                <a href="ListSchedule.aspx" class="btn btn-sm btn-outline-success"><i class="fa-solid fa-calendar-days me-1"></i> Thời khóa biểu</a>
            </div>
        </div>
        <asp:Panel ID="pnlDetails" runat="server" Visible="false" CssClass="mt-3 pt-3 border-top">
            <asp:Literal ID="litResultDetails" runat="server"></asp:Literal>
        </asp:Panel>
    </asp:Panel>

    <div class="card card-custom p-4">
        <ul class="nav nav-pills mb-4 nav-justified" id="importTab" role="tablist">
            <li class="nav-item" role="presentation">
                <button class="nav-link active fw-semibold" id="students-tab" data-bs-toggle="pill" data-bs-target="#tab-students" type="button" role="tab">
                    <i class="fa-solid fa-user-graduate me-2"></i>1. Import Tài Khoản (HS/GV/PH)
                </button>
            </li>
            <li class="nav-item" role="presentation">
                <button class="nav-link fw-semibold" id="schedules-tab" data-bs-toggle="pill" data-bs-target="#tab-schedules" type="button" role="tab">
                    <i class="fa-solid fa-calendar-days me-2"></i>2. Import Thời Khóa Biểu
                </button>
            </li>
            <li class="nav-item" role="presentation">
                <button class="nav-link fw-semibold" id="grades-tab" data-bs-toggle="pill" data-bs-target="#tab-grades" type="button" role="tab">
                    <i class="fa-solid fa-book-bookmark me-2"></i>3. Import Điểm
                </button>
            </li>
        </ul>

        <div class="tab-content" id="importTabContent">
            <!-- TAB 1: ACCOUNTS -->
            <div class="tab-pane fade show active" id="tab-students" role="tabpanel">
                <div class="alert alert-info py-2 small mb-3">
                    <i class="fa-solid fa-info-circle me-1"></i> Cột CSV: <code>fullName,className,phone,email,role,parentPhone</code>.
                    Bắt buộc: họ tên và (số điện thoại hoặc email). <code>role</code> = HS (mặc định), GV hoặc PH. <code>parentPhone</code> liên kết học sinh với phụ huynh (PH) đã có.
                    Trùng số điện thoại/email thì cập nhật; tài khoản mới có mật khẩu mặc định <code>123456</code>.
                    <asp:LinkButton ID="lnkTplStudents" runat="server" OnClick="lnkTplStudents_Click" CausesValidation="false" CssClass="ms-2 fw-semibold"><i class="fa-solid fa-download me-1"></i>Tải tệp mẫu</asp:LinkButton>
                </div>
                <div class="mb-3">
                    <label class="form-label fw-semibold">Chọn file CSV từ máy tính:</label>
                    <asp:FileUpload ID="fuStudents" runat="server" CssClass="form-control" accept=".csv,text/csv,text/plain" />
                </div>
                <div class="mb-3">
                    <label class="form-label fw-semibold">Hoặc dán nội dung CSV:</label>
                    <asp:TextBox ID="txtStudentsCsv" runat="server" TextMode="MultiLine" Rows="6" CssClass="form-control font-monospace small"></asp:TextBox>
                </div>
                <div class="d-flex justify-content-between align-items-center">
                    <button type="button" class="btn btn-sm btn-outline-secondary" onclick="loadSample('<%= txtStudentsCsv.ClientID %>', sampleStudents)"><i class="fa-solid fa-paste me-1"></i> Nạp mẫu</button>
                    <asp:Button ID="btnImportStudents" runat="server" Text="Thực Hiện Import Tài Khoản" CssClass="btn btn-fpt px-4" OnClick="btnImportStudents_Click" />
                </div>
            </div>

            <!-- TAB 2: TIMETABLE -->
            <div class="tab-pane fade" id="tab-schedules" role="tabpanel">
                <div class="alert alert-info py-2 small mb-3">
                    <i class="fa-solid fa-info-circle me-1"></i> Cột CSV: <code>className,subject,dayOfWeek,period,teacher,room,mode,content,prep,note</code>.
                    <code>dayOfWeek</code> = 1-7 (1 = Thứ Hai) hoặc T2-T7/CN; <code>period</code> = 1-8 (giờ học tự động theo tiết); <code>teacher</code> = số điện thoại, email hoặc họ tên của giáo viên (GV).
                    Mỗi lớp + thứ + tiết chỉ có một tiết: trùng thì cập nhật.
                    <asp:LinkButton ID="lnkTplSchedules" runat="server" OnClick="lnkTplSchedules_Click" CausesValidation="false" CssClass="ms-2 fw-semibold"><i class="fa-solid fa-download me-1"></i>Tải tệp mẫu</asp:LinkButton>
                </div>
                <div class="mb-3">
                    <label class="form-label fw-semibold">Chọn file CSV thời khóa biểu:</label>
                    <asp:FileUpload ID="fuSchedules" runat="server" CssClass="form-control" accept=".csv,text/csv,text/plain" />
                </div>
                <div class="mb-3">
                    <label class="form-label fw-semibold">Hoặc dán nội dung CSV thời khóa biểu:</label>
                    <asp:TextBox ID="txtSchedulesCsv" runat="server" TextMode="MultiLine" Rows="6" CssClass="form-control font-monospace small"></asp:TextBox>
                </div>
                <div class="d-flex justify-content-between align-items-center">
                    <button type="button" class="btn btn-sm btn-outline-secondary" onclick="loadSample('<%= txtSchedulesCsv.ClientID %>', sampleSchedules)"><i class="fa-solid fa-paste me-1"></i> Nạp mẫu</button>
                    <asp:Button ID="btnImportSchedules" runat="server" Text="Thực Hiện Import Lịch Học" CssClass="btn btn-fpt px-4" OnClick="btnImportSchedules_Click" />
                </div>
            </div>

            <!-- TAB 3: GRADES -->
            <div class="tab-pane fade" id="tab-grades" role="tabpanel">
                <div class="alert alert-info py-2 small mb-3">
                    <i class="fa-solid fa-info-circle me-1"></i> Cột CSV: <code>student,subject,term,type,score,weight,gradeDate</code>.
                    <code>student</code> = số điện thoại hoặc email của học sinh; <code>type</code> = Miệng, 15 phút, 1 tiết, Giữa kỳ, Cuối kỳ; <code>score</code> 0-10; <code>weight</code> và <code>gradeDate</code> (yyyy-MM-dd) có thể bỏ trống.
                    Trùng học sinh + môn + học kỳ + loại + ngày thì cập nhật điểm.
                    <asp:LinkButton ID="lnkTplGrades" runat="server" OnClick="lnkTplGrades_Click" CausesValidation="false" CssClass="ms-2 fw-semibold"><i class="fa-solid fa-download me-1"></i>Tải tệp mẫu</asp:LinkButton>
                </div>
                <div class="mb-3">
                    <label class="form-label fw-semibold">Chọn file CSV bảng điểm:</label>
                    <asp:FileUpload ID="fuGrades" runat="server" CssClass="form-control" accept=".csv,text/csv,text/plain" />
                </div>
                <div class="mb-3">
                    <label class="form-label fw-semibold">Hoặc dán nội dung CSV bảng điểm:</label>
                    <asp:TextBox ID="txtGradesCsv" runat="server" TextMode="MultiLine" Rows="6" CssClass="form-control font-monospace small"></asp:TextBox>
                </div>
                <div class="d-flex justify-content-between align-items-center">
                    <button type="button" class="btn btn-sm btn-outline-secondary" onclick="loadSample('<%= txtGradesCsv.ClientID %>', sampleGrades)"><i class="fa-solid fa-paste me-1"></i> Nạp mẫu</button>
                    <asp:Button ID="btnImportGrades" runat="server" Text="Thực Hiện Import Điểm" CssClass="btn btn-fpt px-4" OnClick="btnImportGrades_Click" />
                </div>
            </div>
        </div>
    </div>

    <div class="card card-custom p-4 mt-4 border-0 shadow-sm" style="background: linear-gradient(135deg, #F8FAFC 0%, #EFF6FF 100%);">
        <h5 class="fw-bold text-navy mb-2"><i class="fa-solid fa-circle-question me-2 text-primary"></i>Lưu Ý Khi Nhập Dữ Liệu Hàng Loạt</h5>
        <div class="row g-3 text-secondary small">
            <div class="col-md-4">
                <div class="p-3 bg-white rounded-3 border">
                    <div class="fw-bold text-primary mb-1"><i class="fa-solid fa-file-csv me-1"></i> 1. Chuẩn hóa tệp tin</div>
                    Dùng bảng mã UTF-8 để tiếng Việt có dấu hiển thị đúng. Dòng đầu là tiêu đề cột; giá trị có dấu phẩy đặt trong dấu ngoặc kép.
                </div>
            </div>
            <div class="col-md-4">
                <div class="p-3 bg-white rounded-3 border">
                    <div class="fw-bold text-success mb-1"><i class="fa-solid fa-rotate me-1"></i> 2. Có thể chạy lại nhiều lần</div>
                    Tài khoản khớp theo số điện thoại/email, tiết học khớp theo lớp + thứ + tiết nên import lại không tạo dòng trùng.
                </div>
            </div>
            <div class="col-md-4">
                <div class="p-3 bg-white rounded-3 border">
                    <div class="fw-bold text-warning mb-1"><i class="fa-solid fa-shield-halved me-1"></i> 3. An toàn dữ liệu</div>
                    Mỗi lần import chạy trong một giao dịch: dòng lỗi được bỏ qua và liệt kê kèm số dòng; lỗi hệ thống sẽ hoàn tác toàn bộ.
                </div>
            </div>
        </div>
    </div>
</asp:Content>

<asp:Content ID="Scripts" ContentPlaceHolderID="ScriptsContent" runat="server">
    <script>
        var sampleStudents = <%= SampleJs(MyfschoolWeb.Services.ImportService.StudentsTemplate) %>;
        var sampleSchedules = <%= SampleJs(MyfschoolWeb.Services.ImportService.SchedulesTemplate) %>;
        var sampleGrades = <%= SampleJs(MyfschoolWeb.Services.ImportService.GradesTemplate) %>;
        function loadSample(id, text) { document.getElementById(id).value = text; }
    </script>
</asp:Content>
