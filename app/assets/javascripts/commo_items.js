$(document).on("turbolinks:load", function() {

 

  $('#add-freqs-button').click(function() {
    $('#freq-form').show();

    var i;
     for (i = 0; i < freqIds.length; i++) {
      $("#assignment_commo_item_ids_" + freqIds[i] ).prop("checked","true");
    }
  

  });
  $('#cancel-freq-form').click(function() {
    $('#freq-form').hide();
  });

});