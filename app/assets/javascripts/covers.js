$(document).on("turbolinks:load", function() {


  $('.block').click(function() {
      $('.block').removeClass('block-selected');
      $(this).addClass('block-selected');
      if ($(this).hasClass('block-selected')) {
        $(this).prev('.style-controls').toggle();
      }
    }
    );
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
