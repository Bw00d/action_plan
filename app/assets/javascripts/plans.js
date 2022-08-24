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

    $('#plans-index').last('li').addClass("selected");

    $(".tabrow li").click(function(){
      $(".tabrow li").removeClass('selected');
      $(this).addClass('selected');
    })


  // local storage
    $('.plan-row').click(function(){
      var div = $(this).attr("id");
      if ($(this).hasClass('expanded')) {
        $(this).removeClass('expanded');
        localStorage.setItem(div, "closed");
        $(this).next('div').slideUp();
      } 
      else {
      $(this).next('div').slideDown();
      localStorage.setItem(div, "expanded");
      $(this).addClass('expanded');
      }
    });
    if (localStorage.getItem("iap-row") == "expanded") {
      $("#iap-row").next('div').show();
      $("#iap-row").addClass('expanded');
    }
    if (localStorage.getItem("resource-list") == "expanded") {
      $("#resource-list").next('div').show();
      $("#resource-list").addClass('expanded');
    }
    if (localStorage.getItem("objectives-list") == "expanded") {
      $("#objectives-list").next('div').show();
      $("#objectives-list").addClass('expanded');
    }
    if (localStorage.getItem("situation-content") == "expanded") {
      $("#situation-content").next('div').show();
      $("#situation-content").addClass('expanded');
    }
    if (localStorage.getItem("activity-list") == "expanded") {
      $("#activity-list").next('div').show();
      $("#activity-list").addClass('expanded');
    }

// $('.plan-row')
//   .click(localStorage.getItem('bgColor'))
//   .click(function() {
//       $('body').css({'background-color': this.value});
//       localStorage.setItem('bgColor', this.value);
//   })
//   .change();
 
});

