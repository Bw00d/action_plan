$(document).on("turbolinks:load", function() {

 

  $('#add-freqs').click(function() {
    $('#freq-form').show();
  });
  $('#cancel-freq-form').click(function() {
    $('#freq-form').hide();
  });
});