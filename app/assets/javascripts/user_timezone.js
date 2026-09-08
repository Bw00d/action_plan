// Detects the browser's IANA timezone (e.g. "America/Anchorage") on
// page load and posts it to the server if the current user hasn't set
// one yet. The server endpoint is idempotent and only writes when the
// user.time_zone column is blank, so a manual selection via the profile
// edit page is preserved.
//
// A meta tag `<meta name="user-tz-needed" content="1">` gates the call
// so the request only fires when there's actually a user record to
// update AND that user has no timezone set. See layouts/application.
$(document).on("turbolinks:load", function () {
  var meta = document.querySelector('meta[name="user-tz-needed"]');
  if (!meta || meta.content !== "1") return;

  var tz;
  try {
    tz = Intl.DateTimeFormat().resolvedOptions().timeZone;
  } catch (e) { return; }
  if (!tz) return;

  var token = document.querySelector('meta[name="csrf-token"]');
  fetch("/users/detect_timezone", {
    method: "PATCH",
    credentials: "same-origin",
    headers: {
      "Content-Type": "application/json",
      "Accept": "application/json",
      "X-CSRF-Token": token ? token.content : ""
    },
    body: JSON.stringify({ time_zone: tz })
  }).then(function (r) {
    // On success the next page load will pick up the new zone via the
    // ApplicationController around_action. Nothing to do here.
    if (!r.ok && window.console) console.warn("timezone detect failed:", r.status);
  }).catch(function (err) {
    if (window.console) console.warn("timezone detect error:", err);
  });

  // Prevent repeat calls if the user navigates within the same tab
  // (turbolinks:load fires per navigation).
  meta.content = "0";
});
