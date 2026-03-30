(function () {
  var s = document.querySelector('script[src*="shared.js"]');
  var root = s ? s.getAttribute('src').replace('shared.js', '') : '';

  var nav = document.getElementById('site-nav');
  if (nav) {
    nav.outerHTML =
      '<header class="site-header">' +
        '<a href="' + root + '" class="site-logo">Triovel</a>' +
        '<nav class="site-links">' +
          '<a href="' + root + 'privacy-policy">Privacy</a>' +
          '<a href="' + root + 'terms-and-conditions">Terms</a>' +
          '<a href="https://apps.apple.com/app/triovel/id000000000" class="site-cta">Get the app</a>' +
        '</nav>' +
      '</header>';
  }

  var footer = document.getElementById('site-footer');
  if (footer) {
    footer.outerHTML =
      '<footer class="site-footer">' +
        '<div class="footer-inner">' +
          '<div class="footer-left">' +
            '<span class="footer-logo">Triovel</span>' +
            '<span class="footer-copy">&copy; ' + new Date().getFullYear() + '</span>' +
          '</div>' +
          '<div class="footer-links">' +
            '<a href="' + root + 'privacy-policy">Privacy</a>' +
            '<a href="' + root + 'terms-and-conditions">Terms</a>' +
            '<a href="mailto:support@triovel.app">Contact</a>' +
          '</div>' +
        '</div>' +
      '</footer>';
  }
})();
