// This is a manifest file that'll be compiled into application.js, which will include all the files
// listed below.
//
// Any JavaScript/Coffee file within this directory, lib/assets/javascripts, or any plugin's
// vendor/assets/javascripts directory can be referenced here using a relative path.
//
// It's not advisable to add code directly here, but if you do, it'll appear at the bottom of the
// compiled file. JavaScript code in this file should be added after the last require_* statement.
//
// Read Sprockets README (https://github.com/rails/sprockets#sprockets-directives) for details
// about supported directives.
//
//= require jquery
// As of Rails 5.1, jquery_ujs was replaced by rails-ujs, which does not
// depend on jQuery but can be used with applications that use jQuery. This
// application uses jQuery and we've chosen to use jquery_ujs instead of
// rails-ujs, mainly because it makes it easier to override $.rails.allowAction
// to replace JavaScript confirmation dialogs with application-specific modals.
//= require jquery_ujs
// Only load the jQuery UI widgets this app actually uses (sortable for
// the T-card board, draggable for the cover canvas). The full
// jquery-ui bundle included the Datepicker widget, which carries
// GHSA-h6gj-6jjq-h8g9 (CVE-2022-31160) — XSS in Datepicker's `*Text`
// options. We use bootstrap-datepicker (loaded below), not jQuery UI's
// datepicker, so narrowing the require ships zero datepicker code
// from jQuery UI → the vulnerable code path isn't reachable from the
// browser at all.
//= require jquery-ui/widgets/sortable
//= require jquery-ui/widgets/draggable
//= require turbolinks
//= require bootstrap-sprockets
//= require bootstrap-datepicker
//= require select2
//= require sweetalert2/dist/sweetalert2
//= require best_in_place
//= require date/extras
//= require jquery.validate
//= require flatpickr
//= require_tree .
