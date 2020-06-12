$(document).on("turbolinks:load", function() {

  $('.blank-row').hover(function() {
        $('.commo-item-form').first().show();
      }, 
      function () {
        $('.commo-item-form').first().hide();
      }
    );
});