/* MyFSchool admin web: shell behaviour + small helpers. No dependencies. */
(function () {
  'use strict';
  var doc = document, body = doc.body;

  /* ---- off-canvas sidebar (under 992px) ---- */
  var toggle = doc.getElementById('sidebarToggle');
  var sidebar = doc.getElementById('appSidebar');
  var backdrop = doc.getElementById('sidebarBackdrop');
  function setSidebar(open, restoreFocus) {
    if (!toggle || !sidebar) return;
    body.classList.toggle('sidebar-open', open);
    toggle.setAttribute('aria-expanded', open ? 'true' : 'false');
    toggle.setAttribute('aria-label', open ? 'Đóng menu' : 'Mở menu');
    if (open) {
      var first = sidebar.querySelector('a[href]');
      if (first) first.focus();
    } else if (restoreFocus) {
      toggle.focus();
    }
  }
  if (toggle && sidebar) {
    toggle.addEventListener('click', function () { setSidebar(!body.classList.contains('sidebar-open'), false); });
    if (backdrop) backdrop.addEventListener('click', function () { setSidebar(false, true); });
    sidebar.addEventListener('click', function (e) {
      var a = e.target.closest ? e.target.closest('a[href]') : null;
      if (a) setSidebar(false, false);
    });
    doc.addEventListener('keydown', function (e) {
      if (e.key === 'Escape' && body.classList.contains('sidebar-open')) { setSidebar(false, true); }
    });
    var mq = window.matchMedia ? window.matchMedia('(min-width: 992px)') : null;
    if (mq) {
      var onChange = function () { if (mq.matches) { body.classList.remove('sidebar-open'); toggle.setAttribute('aria-expanded', 'false'); } };
      if (mq.addEventListener) mq.addEventListener('change', onChange); else if (mq.addListener) mq.addListener(onChange);
    }
  }

  /* ---- password show/hide: <button type="button" data-toggle-password="inputId" aria-pressed="false"> ---- */
  Array.prototype.forEach.call(doc.querySelectorAll('[data-toggle-password]'), function (btn) {
    btn.addEventListener('click', function () {
      var input = doc.getElementById(btn.getAttribute('data-toggle-password'));
      if (!input) return;
      var show = input.type === 'password';
      input.type = show ? 'text' : 'password';
      btn.setAttribute('aria-pressed', show ? 'true' : 'false');
      btn.setAttribute('aria-label', show ? 'Ẩn mật khẩu' : 'Hiện mật khẩu');
      btn.setAttribute('title', show ? 'Ẩn mật khẩu' : 'Hiện mật khẩu');
      var icon = btn.querySelector('i');
      if (icon) { icon.className = show ? 'fa-solid fa-eye-slash' : 'fa-solid fa-eye'; }
      input.focus();
    });
  });

  /* ---- loading state on submit: <form data-loading-form> with <input|button data-loading-text="Đang xử lý..."> ----
     The button is NOT disabled (a disabled submit button is not posted, which would break ASP.NET click events);
     a second submit is blocked instead. */
  Array.prototype.forEach.call(doc.querySelectorAll('form'), function (form) {
    var btn = form.querySelector('[data-loading-text]');
    if (!btn) return;
    var busy = false;
    form.addEventListener('submit', function (e) {
      if (busy) { e.preventDefault(); return; }
      busy = true;
      form.setAttribute('aria-busy', 'true');
      btn.classList.add('is-loading');
      btn.setAttribute('aria-disabled', 'true');
      var spin = form.querySelector('.btn-spinner');
      if (spin) spin.classList.add('is-on');
      var text = btn.getAttribute('data-loading-text');
      setTimeout(function () { if (btn.tagName === 'INPUT') btn.value = text; else if (text) btn.lastChild.textContent = ' ' + text; }, 0);
    });
    window.addEventListener('pageshow', function (ev) {   // back button: reset
      if (ev.persisted) { busy = false; btn.classList.remove('is-loading'); btn.removeAttribute('aria-disabled'); form.removeAttribute('aria-busy'); }
    });
  });

  /* ---- announce + focus a server-rendered alert (role=alert) so screen readers read it ---- */
  var alertEl = doc.querySelector('[data-autofocus-alert]');
  if (alertEl) { alertEl.setAttribute('tabindex', '-1'); alertEl.focus(); }

  /* ---- toast helper: MyF.toast('Đã lưu', 'success') ---- */
  var icons = { success: 'fa-circle-check', error: 'fa-circle-xmark', warning: 'fa-triangle-exclamation', info: 'fa-circle-info' };
  window.MyF = window.MyF || {};
  window.MyF.toast = function (message, variant) {
    variant = icons[variant] ? variant : 'info';
    var region = doc.querySelector('.toast-region');
    if (!region) {
      region = doc.createElement('div');
      region.className = 'toast-region';
      region.setAttribute('role', 'status');
      region.setAttribute('aria-live', 'polite');
      body.appendChild(region);
    }
    var t = doc.createElement('div');
    t.className = 'app-toast is-' + variant;
    var i = doc.createElement('i'); i.className = 'fa-solid ' + icons[variant]; i.setAttribute('aria-hidden', 'true');
    var s = doc.createElement('span'); s.textContent = message;
    t.appendChild(i); t.appendChild(s); region.appendChild(t);
    setTimeout(function () { if (t.parentNode) t.parentNode.removeChild(t); }, 4500);
  };
})();
