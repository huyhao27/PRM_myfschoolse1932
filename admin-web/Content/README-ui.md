# UI kit (Content/site.css) - dung cho moi trang

Nguon thiet ke: `design-system/myfschool/MASTER.md` (thu muc goc repo). Thu tu nap CSS: Bootstrap 5.3, Font Awesome 6, `Content/site.css` (Site.Master da nap san). Khong viet mau co dinh (hex) trong trang: dung bien `var(--brand-strong)`, `var(--line)`, ... Khong them `<style>` trong trang; bo cac class cu `btn-fpt`, `card-custom`, `card-header-fpt`, `table-custom` (con duoc giu lam alias tam thoi).

Tokens chinh: `--brand #F37021` (be mat lon, icon), `--brand-strong #C2410C` (chu cam, nut chinh), `--brand-soft`, `--navy`, `--ink`, `--muted`, `--line`, `--surface`, `--surface-alt`, `--success|warning|danger|info` (+ `-soft`), `--space-1..7`, `--radius-control|card|hero|pill`, `--hit` (44px). Icon: Font Awesome solid, `aria-hidden="true"` khi chi de trang tri. Khong dung emoji lam icon.

## Page header
```html
<div class="page-header">
  <div class="page-header-text">
    <h1>Don tu</h1>
    <p class="page-desc">Duyet don xin nghi hoc va cac don khac.</p>
  </div>
  <div class="page-actions">
    <a class="btn-brand" href="AddX.aspx"><i class="fa-solid fa-plus" aria-hidden="true"></i>Them moi</a>
  </div>
</div>
```

## Card panel
```html
<section class="card-panel" aria-labelledby="t1">
  <div class="card-panel-header"><h2 id="t1">Tieu de</h2> <a class="btn-brand-outline btn-sm-brand" href="#">Xem tat ca</a></div>
  <div class="card-panel-body">Noi dung</div>
  <div class="card-panel-footer">Chan (tuy chon)</div>
</section>
```
Bo cuc: `.grid-2` (2 cot, 1 cot duoi 992px), `.grid-stack`, `.stack`.

## Toolbar / filter bar / chips
```html
<div class="filter-bar">
  <div class="filter-group"><label for="ddlClass">Lop</label><asp:DropDownList ID="ddlClass" runat="server" CssClass="form-select" /></div>
  <div class="filter-group"><label for="txtQ">Tim kiem</label><asp:TextBox ID="txtQ" runat="server" CssClass="form-control" /></div>
  <div class="spacer"></div>
  <button class="btn-brand" type="submit">Loc</button>
</div>
<div class="chips"><a class="chip is-active" href="?status=ALL">Tat ca</a><a class="chip" href="?status=pending">Cho duyet</a></div>
```

## Data table (GridView: CssClass="data-table", GridLines="None", UseAccessibleHeader="true")
```html
<div class="table-responsive-stack">
  <table class="data-table">
    <tr><th>Ho ten</th><th class="num">Diem</th><th>Trang thai</th><th class="num">Thao tac</th></tr>
    <tr><td>Nguyen Van A</td><td class="num">8.5</td><td><span class="status-badge is-approved"><i class="fa-solid fa-circle-check" aria-hidden="true"></i>Da duyet</span></td>
        <td class="actions"><a class="icon-btn" href="#" title="Xem" aria-label="Xem chi tiet"><i class="fa-solid fa-eye" aria-hidden="true"></i></a></td></tr>
  </table>
</div>
```
Header dinh, ke soc, hang >= 44px, so dung `class="num"` (can phai, tabular). Duoi 768px co the them `is-stacked` vao table va `data-label="Cot"` cho moi `td` de thanh dang the. Trong GridView: `ItemStyle-CssClass="num"`, `HeaderStyle-CssClass="num"`, cot hanh dong `ItemStyle-CssClass="actions"`.

## Status badge (luon icon + chu)
```html
<span class="status-badge is-pending"><i class="fa-solid fa-hourglass-half" aria-hidden="true"></i>Cho duyet</span>
<span class="status-badge is-approved"><i class="fa-solid fa-circle-check" aria-hidden="true"></i>Da duyet</span>
<span class="status-badge is-rejected"><i class="fa-solid fa-circle-xmark" aria-hidden="true"></i>Tu choi</span>
<span class="status-badge is-info"><i class="fa-solid fa-circle-info" aria-hidden="true"></i>Thong tin</span>
```

## Buttons
```html
<a class="btn-brand" href="#">Chinh</a>   <button class="btn-brand-outline" type="button">Phu</button>   <button class="btn-danger-soft" type="button">Xoa</button>
<button class="btn-brand" type="submit" data-loading-text="Dang luu..."><span class="btn-spinner" aria-hidden="true"></span>Luu</button>
<a class="icon-btn" href="#" title="Chinh sua" aria-label="Chinh sua"><i class="fa-solid fa-pen-to-square" aria-hidden="true"></i></a>
```
`asp:Button CssClass="btn-brand"` dung duoc. `icon-btn` luon co `title` va `aria-label`; them `is-danger`, `has-border` neu can. `btn-block` (full width), `btn-sm-brand` (36px).

## Form field
```html
<div class="form-field has-error">
  <label for="txtName">Ho ten <span class="req" aria-hidden="true">*</span></label>
  <asp:TextBox ID="txtName" runat="server" CssClass="form-control" aria-describedby="nameHelp nameErr" />
  <span class="form-help" id="nameHelp">Ghi dung nhu tren giay khai sinh.</span>
  <span class="field-error" id="nameErr"><i class="fa-solid fa-circle-exclamation" aria-hidden="true"></i>Vui long nhap ho ten.</span>
</div>
<div class="form-actions"><button class="btn-brand">Luu</button><a class="btn-brand-outline" href="List.aspx">Huy</a></div>
```
Label o tren, loi o duoi truong voi icon (khong chi bang mau). Truong mat khau co the them nut hien/an: `<div class="input-affix">` + `<button type="button" class="icon-btn" data-toggle-password="inputId" aria-pressed="false" aria-label="Hien mat khau">`.

## Stat card
```html
<div class="stat-grid">
  <a class="stat-card" href="ListRequest.aspx?status=pending">
    <span class="stat-icon is-warning" aria-hidden="true"><i class="fa-solid fa-envelope-open-text"></i></span>
    <div class="stat-body"><span class="stat-label">Don cho duyet</span><p class="stat-value">3</p><span class="stat-meta">Ghi chu</span></div>
  </a>
</div>
```
Mau icon: mac dinh info, `is-brand`, `is-success`, `is-warning`, `is-danger`.

## Empty state
```html
<div class="empty-state">
  <div class="empty-icon" aria-hidden="true"><i class="fa-solid fa-inbox"></i></div>
  <h3 class="empty-title">Chua co don tu nao</h3>
  <p>Don tu hoc sinh gui se hien o day.</p>
  <a class="btn-brand" href="#">Hanh dong dau tien</a>
</div>
```

## Alert inline va toast
```html
<div class="alert-inline is-success" role="status"><i class="fa-solid fa-circle-check" aria-hidden="true"></i><span class="alert-text">Da luu.</span></div>
<div class="alert-inline is-error" role="alert"><i class="fa-solid fa-triangle-exclamation" aria-hidden="true"></i><span class="alert-text">Khong luu duoc.</span></div>
```
Bien the: `is-success`, `is-error`, `is-warning`, `is-info`. Toast (khong dung `.toast` cua Bootstrap): `MyF.toast('Da luu', 'success')` (site.js; `success|error|warning|info`).

## Thanh ti le truy cap (chu + so luon hien, thanh chi de trang tri)
```html
<div class="meter-row">
  <div class="meter-label"><span class="meter-name is-approved"><i class="fa-solid fa-circle-check" aria-hidden="true"></i>Tot</span><span class="meter-value">12 mon (40%)</span></div>
  <div class="meter-track" aria-hidden="true"><div class="meter-fill is-approved" style="width:40%"></div></div>
</div>
```

## Khung trang (Site.Master)
Sidebar trai 240px (off-canvas duoi 992px, nut `#sidebarToggle`, dong bang Escape / bam link), top bar, `<main id="main-content">`. Trang con chi viet noi dung trong `MainContent`; tieu de trang = `Title` trong `<%@ Page %>` (hien o top bar), muc `h1` nam trong `.page-header`. Muc menu dang mo co `aria-current="page"` tu dong.
