$(document).on("turbolinks:load", function() {


  $('.cover-block').hover(function() {
        $(this).find('.add-block-button').show();
      }, 
      function () {
        $(this).find('.add-block-button').hide();
      }
    );
  $('.add-block-button').hover(function() {
        $(this).show();
      }, 
      function () {
        $(this).hide();
      }
    );
});