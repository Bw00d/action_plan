$(document).on("turbolinks:load", function() {


  $('.blank-row').hover(function() {
        $(this).find('.team-form').show();
      }, 
      function () {
        $(this).find('.team-form').hide();
      }
    );
});