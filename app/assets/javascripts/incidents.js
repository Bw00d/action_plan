$(document).on("turbolinks:load", function() {

  $('.datepicker').datepicker();

   // Incidents

  $("#show-incident-form").click(function () {
    $("#edit-incident-form").toggle();
  });

  // Incident Objectives

  $("#new-objective").click(function () {
    $("#new-objective").hide();
    $("#objective-form").show();
  });

  // Incident Activites
  $("#new-activity").click(function () {
    $("#new-activity").hide();
    $("#activity-form").show();
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