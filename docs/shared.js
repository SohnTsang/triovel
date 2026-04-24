(function () {
  var s = document.querySelector('script[src*="shared.js"]');
  var root = s ? s.getAttribute('src').replace('shared.js', '') : '';

  // Inject Pacifico font once — single source for all pages
  if (!document.querySelector('link[href*="Pacifico"]')) {
    var preconnect1 = document.createElement('link');
    preconnect1.rel = 'preconnect';
    preconnect1.href = 'https://fonts.googleapis.com';
    document.head.appendChild(preconnect1);

    var preconnect2 = document.createElement('link');
    preconnect2.rel = 'preconnect';
    preconnect2.href = 'https://fonts.gstatic.com';
    preconnect2.crossOrigin = 'anonymous';
    document.head.appendChild(preconnect2);

    var fontLink = document.createElement('link');
    fontLink.rel = 'stylesheet';
    fontLink.href = 'https://fonts.googleapis.com/css2?family=Pacifico&display=swap';
    document.head.appendChild(fontLink);
  }

  // Header
  var nav = document.getElementById('site-nav');
  if (nav) {
    nav.outerHTML =
      '<header class="site-header">' +
        '<a href="' + root + '" class="site-logo">Triovel</a>' +
        '<nav class="site-links">' +
          '<a href="' + root + 'privacy-policy">Privacy</a>' +
          '<a href="' + root + 'terms-and-conditions">Terms</a>' +
          '<a href="https://apps.apple.com/app/triovel/id6761365602" class="site-cta">Get the app</a>' +
        '</nav>' +
      '</header>';
  }

  // Footer
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
