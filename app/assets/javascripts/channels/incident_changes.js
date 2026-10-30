// "Someone else changed this incident" notices.
//
// Every incident page carries data-live-incident-id on <body> (see
// layouts/application.html.erb). We subscribe to IncidentChannel for that
// incident; when another user saves a tracked record the server
// broadcasts { area, user_id, user_name } and we show a small banner with
// a Refresh button. Our own edits are ignored (matched on user id).
(function () {
  var subscription = null;
  var subscribedIncident = null;
  // area -> Set-like object of user names, for the banner text.
  var changes = {};

  function toSentence(list) {
    if (list.length <= 1) return list.join('');
    return list.slice(0, -1).join(', ') + ' and ' + list[list.length - 1];
  }

  function renderNotice() {
    var areas = Object.keys(changes);
    if (!areas.length) return;

    var names = {};
    areas.forEach(function (a) { Object.keys(changes[a]).forEach(function (n) { names[n] = true; }); });

    var $notice = $('#live-change-notice');
    if (!$notice.length) {
      $notice = $(
        '<div id="live-change-notice" class="live-change-notice no-print" role="status">' +
          '<span class="live-change-text"></span>' +
          '<button type="button" class="btn btn-primary btn-xs live-change-refresh">Refresh</button>' +
          '<button type="button" class="live-change-dismiss" aria-label="Dismiss">&times;</button>' +
        '</div>'
      ).appendTo(document.body);
    }
    $notice.find('.live-change-text').text(
      toSentence(Object.keys(names)) + ' updated ' + toSentence(areas) + '.'
    );
  }

  function clearNotice() {
    changes = {};
    $('#live-change-notice').remove();
  }

  $(document).on('click', '.live-change-refresh', function () { window.location.reload(); });
  $(document).on('click', '.live-change-dismiss', clearNotice);

  // Don't let Turbolinks' cached page snapshot replay a stale banner.
  $(document).on('turbolinks:before-cache', clearNotice);

  $(document).on('turbolinks:load', function () {
    // A fresh page load means fresh data — start with no notice.
    changes = {};

    var incidentId = document.body.getAttribute('data-live-incident-id');
    if (incidentId === subscribedIncident) return;

    if (subscription) {
      subscription.unsubscribe();
      subscription = null;
      subscribedIncident = null;
    }
    if (!incidentId || !window.App || !App.cable) return;

    subscribedIncident = incidentId;
    subscription = App.cable.subscriptions.create(
      { channel: 'IncidentChannel', incident_id: incidentId },
      {
        received: function (data) {
          var me = document.body.getAttribute('data-live-user-id');
          if (data.user_id != null && String(data.user_id) === me) return;
          var area = data.area || 'this incident';
          changes[area] = changes[area] || {};
          changes[area][data.user_name || 'Someone'] = true;
          renderNotice();
        }
      }
    );
  });
})();
