$(document).on("turbolinks:load", function() {
   /* Activating Best In Place */
    jQuery(".best_in_place").best_in_place();

    $("#content").find("[id^='tab']").hide(); // Hide all content
    $("#tabs li:first").attr("id","current"); // Activate the first tab
    $("#content #tab1").fadeIn(); // Show first tab's content
    
    $('#tabs a').click(function(e) {
        e.preventDefault();
        if ($(this).closest("li").attr("id") == "current"){ //detection for current tab
         return;       
        }
        else{             
          $("#content").find("[id^='tab']").hide(); // Hide all content
          $("#tabs li").attr("id",""); //Reset id's
          $(this).parent().attr("id","current"); // Activate this
          $('#' + $(this).attr('name')).fadeIn(); // Show content for the current tab
        }
    });

  $(".plan-row").click(function () {
     if($(this).hasClass('expanded')) {
       $(this).next('div').slideUp();
       $(this).removeClass('expanded');
      } else {
        $(this).addClass('expanded');
        $(this).next('div').slideDown();
      }
  });

  $("#new-objective").click(function () {
    $("#new-objective").hide();
    $("#objective-form").show();
  });
});
