$(document).on("turbolinks:load", function() {

  $('.datepicker').datepicker({
    assumeNearbyYear: true
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

  $("#new-resource").click(function () {
    $("#new-resource").hide();
    $("#resource-form").show();
  });

  $('#cancel-resource-button').click(function() {
    $('#resource-form').hide();
    $("#new-resource").show();
    $("html, body").animate({ scrollTop: 0 }, "slow");
    return false;
  });
});