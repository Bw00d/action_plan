$(document).on("turbolinks:load", function() {

  $('#assign-resources-row').hover(function() {
        $('#assign-resources-button').show();
      }, 
      function () {
        $('#assign-resources-button').hide();
      }
    );

  $('#add-freqs-row').hover(function() {
        $('#add-freqs').show();
      }, 
      function () {
        $('#add-freqs').hide();
      }
    );
  $('#assign-resources-button').click(function() {
    $('#resource-assignments-form').show();
  });
  $('#cancel-resource-assignments-form').click(function() {
    $('#resource-assignments-form').hide();
  });

});