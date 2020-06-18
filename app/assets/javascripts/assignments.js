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
  
    var i;
     for (i = 0; i < resourceIds.length; i++) {
      $("#assignment_resource_ids_" + resourceIds[i] ).prop("checked","true");
    }
  });
  $('#cancel-resource-assignments-form').click(function() {
    $('#resource-assignments-form').hide();
  });

});