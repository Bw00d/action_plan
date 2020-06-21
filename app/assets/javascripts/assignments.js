$(document).on("turbolinks:load", function() {


  $('table#assigned-resources').hover(function() {
        $('#assign-resources-button').show();
      }, 
      function () {
        $('#assign-resources-button').hide();
      }
    );
  $('#assign-resources-button').hover(function() {
      $(this).show();
    }, 
    function () {
      $(this).hide();
    }
  );

  $('#commo-table').hover(function() {
      $('#add-freqs-button').show();
    }, 
    function () {
      $('#add-freqs-button').hide();
    }
  );
  $('#add-freqs-button').hover(function() {
      $(this).show();
    }, 
    function () {
      $(this).hide();
    }
  );

  $('#ops-resources').click(function() {    // adding operations
    $('#ops-resource-form').show();
  
    var i;
     for (i = 0; i < opsIds.length; i++) {
      $("#assignment_ops_personnel_ids_" + opsIds[i] ).prop("checked","true");
    }
  }); 
  $('#cancel-ops-form').click(function() {
    $('#ops-resource-form').hide();
  });


  $('#assign-resources-button').click(function() {    // adding resources
    $('#resource-assignments-form').show();
  
    var i;
     for (i = 0; i < resourceIds.length; i++) {
      $("#assignment_resource_ids_" + resourceIds[i] ).prop("checked","true");
    }
  }); 
  $('#cancel-resource-assignments-form').click(function() {
    $('#resource-assignments-form').hide();
  });


  $('#ops-box-container').hover(function() {
        $('#ops-resources').show();
      }, 
      function () {
        $('#ops-resources').hide();
      }
    );
  $('#ops-resources').hover(function() {
      $(this).show();
    }, 
    function () {
      $(this).hide();
    }
  );
  $('#ops-resources').click(function() {
    $('#ops-resource-form').show();
  });

});