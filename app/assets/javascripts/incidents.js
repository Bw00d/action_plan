$(document).on("turbolinks:load", function() {

  $('.datepicker').datepicker({
    assumeNearbyYear: true,
    autoclose: true,
    todayHighlight: true
  });

   // Incidents

  $("#show-incident-form").click(function () {
    $("#edit-incident-form").toggle();
  });

  // Incident Objectives

  $("#new-objective").click(function () {
    $("#new-objective").hide();
    $("#objective-form").show();
  });

  $("#cancel-objective-form").click(function () {
    $("#new-objective").show();
    $("#objective-form").hide();
  });



  // Incident Activites
  $("#new-activity").click(function () {
    $("#new-activity").hide();
    $("#activity-form").show();
  });

  $("#cancel-activity-form").click(function () {
    $("#new-activity").show();
    $("#activity-form").hide();
  });

  // Incident Resources

  // $("#new-resource").click(function () {
  //   $("#new-resource").hide();
  //   $("#resource-form").show();
  // });

  $('#cancel-resource-button').click(function() {
    $('#resource-form').hide();
    $("#new-resource").show();
    $("html, body").animate({ scrollTop: 0 }, "slow");
    return false;
  });

  // new incident ui

  $('.form-incident-name').show();
  $('.attribute').on('keyup', function() {
    if ($(this).val() !== '') {
      // $('div.next-btn-container').css('visibility', 'visible');
      $(this).next('div.next-btn-container').css('visibility', 'visible');
    }
  });
  $('.start-date-picker').on('click', function() {
    $(this).next('div.next-btn-container').css('visibility', 'visible');
  });
  $('.next-btn').click(function(){
    $(this).closest('.form-attributes').next(':hidden:first').fadeIn(1000).show();
    $(this).closest('.form-attributes').hide();
  })

 
});