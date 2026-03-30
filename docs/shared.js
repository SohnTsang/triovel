// Shared nav + footer for all Triovel pages.
// Each page includes <script src="shared.js"> or <script src="../shared.js">
// and has <div id="site-nav"></div> at top and <div id="site-footer"></div> at bottom.

(function () {
  var root = document.querySelector('script[src*="shared.js"]').getAttribute('src').replace('shared.js', '');

  // Nav
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

  // Footer
  var footer = document.getElementById('site-footer');
  if (footer) {
    var year = new Date().getFullYear();
    footer.outerHTML =
      '<footer class="site-footer">' +
        '<div class="footer-inner">' +
          '<div class="footer-left">' +
            '<a href="' + root + '" class="footer-logo">Triovel</a>' +
            '<span class="footer-copy">&copy; ' + year + '</span>' +
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
