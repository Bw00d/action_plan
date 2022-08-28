$(document).on("turbolinks:load", function() {
  $("#demob-form :input").change(function() {
    $('#print-demob-button').hide();
    $('#demob-form-button').show();
  });
});// Place all the behaviors and hooks related to the matching controller here.
// All this logic will automatically be available in application.js.
