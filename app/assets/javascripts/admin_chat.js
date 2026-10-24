// Admin Chat UI (/admin/chat).
//
// Submits each user turn as JSON to /admin/chat/messages, appends the
// returned assistant text, and renders any proposals as yellow cards
// with an Approve button. Approve POSTs to /admin/chat/approvals,
// which calls the actual mutation server-side (demob commit, etc.).
// The log also preserves earlier turns rendered server-side.
(function () {
  'use strict';

  function init() {
    var form = document.getElementById('admin-chat-form');
    if (!form) return;
    var log  = document.getElementById('admin-chat-log');
    var ta   = form.querySelector('textarea[name="message"]');

    // Submit on Enter, newline on Shift+Enter — standard chat UX.
    ta.addEventListener('keydown', function (e) {
      if (e.key === 'Enter' && !e.shiftKey) {
        e.preventDefault();
        form.requestSubmit ? form.requestSubmit() : form.dispatchEvent(new Event('submit', { cancelable: true }));
      }
    });

    form.addEventListener('submit', function (e) {
      e.preventDefault();
      var text = (ta.value || '').trim();
      if (!text) return;

      appendBubble('user', text);
      ta.value = '';
      submitStreaming(text);
    });

    // ── Streaming submit ────────────────────────────────────────
    // Opens a POST and reads back Server-Sent Events: each event is
    // `data: {json}\n\n`. Dispatches events to update the chat UI in
    // real time (text appearing as tokens, tool indicators, proposals).
    function submitStreaming(text) {
      var bubble = null;            // current assistant bubble (lazy-created)
      var bodyEl = null;            // text node container inside bubble
      var toolBanner = appendToolBanner('Claude is thinking');

      fetch(form.dataset.url, {
        method: 'POST',
        credentials: 'same-origin',
        headers: {
          'Content-Type': 'application/json',
          'Accept':       'text/event-stream',
          'X-CSRF-Token': csrfToken()
        },
        body: JSON.stringify({ message: text })
      })
      .then(function (resp) {
        if (!resp.ok || !resp.body) {
          throw new Error('HTTP ' + resp.status);
        }
        var reader  = resp.body.getReader();
        var decoder = new TextDecoder();
        var buf     = '';

        function pump() {
          return reader.read().then(function (step) {
            if (step.done) return;
            buf += decoder.decode(step.value, { stream: true });

            // SSE events are separated by a blank line.
            var parts = buf.split('\n\n');
            buf = parts.pop();        // the trailing (incomplete) event
            for (var i = 0; i < parts.length; i++) {
              var evt = parseSseEvent(parts[i]);
              if (evt) handleEvent(evt);
            }
            return pump();
          });
        }
        return pump();
      })
      .catch(function (err) {
        if (toolBanner) toolBanner.remove();
        appendBubble('system', 'Network error: ' + err.message);
      })
      .finally(function () {
        if (toolBanner) toolBanner.remove();
      });

      function handleEvent(evt) {
        switch (evt.type) {
          case 'text_delta':
            if (!bubble) {
              bubble = appendBubble('assistant', '');
              bodyEl = bubble.querySelector('.admin-chat-msg-body');
              bodyEl.textContent = '';
              // Fresh assistant turn — drop the thinking banner.
              if (toolBanner) { toolBanner.remove(); toolBanner = null; }
            }
            bodyEl.textContent += evt.chunk;
            scrollToBottom();
            break;

          case 'tool_start':
            if (toolBanner) toolBanner.remove();
            toolBanner = appendToolBanner('Using ' + evt.name + ' — ' + (evt.input_summary || ''));
            // Any text so far is a complete assistant turn before the
            // next tool call; detach so the next text_delta starts a
            // new bubble below the tool banner.
            bubble = null;
            bodyEl = null;
            break;

          case 'tool_result':
            if (toolBanner) {
              toolBanner.textContent = (evt.ok ? '✓ ' : '✗ ') + toolBanner.textContent.replace(/^(Using |✓ |✗ )/, 'Using ');
              toolBanner.classList.add(evt.ok ? 'is-ok' : 'is-error');
            }
            break;

          case 'proposal':
            appendProposal(evt.payload);
            break;

          case 'error':
            if (toolBanner) { toolBanner.remove(); toolBanner = null; }
            appendBubble('system', 'Error: ' + evt.message);
            break;

          case 'done':
            if (toolBanner) { toolBanner.remove(); toolBanner = null; }
            break;
        }
      }
    }

    function parseSseEvent(raw) {
      // Each event is one or more lines; we only use `data:`.
      var lines = raw.split('\n');
      var dataParts = [];
      for (var i = 0; i < lines.length; i++) {
        var m = /^data:\s?(.*)$/.exec(lines[i]);
        if (m) dataParts.push(m[1]);
      }
      if (!dataParts.length) return null;
      try   { return JSON.parse(dataParts.join('\n')); }
      catch (e) { return null; }
    }

    scrollToBottom();

    // ── helpers ────────────────────────────────────────────────
    function appendBubble(role, text) {
      var wrap = document.createElement('div');
      wrap.className = 'admin-chat-msg admin-chat-msg-' + role;

      var r = document.createElement('div');
      r.className = 'admin-chat-msg-role';
      r.textContent = role.charAt(0).toUpperCase() + role.slice(1);
      wrap.appendChild(r);

      var body = document.createElement('div');
      body.className = 'admin-chat-msg-body';
      // simple_format-ish: paragraphs on blank lines, br on single lines
      text.split(/\n\n+/).forEach(function (para) {
        var p = document.createElement('p');
        para.split('\n').forEach(function (line, i, arr) {
          p.appendChild(document.createTextNode(line));
          if (i < arr.length - 1) p.appendChild(document.createElement('br'));
        });
        body.appendChild(p);
      });
      wrap.appendChild(body);
      log.appendChild(wrap);
      scrollToBottom();
      return wrap;
    }

    function appendProposal(prop) {
      var card = document.createElement('div');
      card.className = 'admin-chat-proposal';
      card.innerHTML =
        '<h5>Proposed demob — needs your approval</h5>' +
        '<dl>' +
          field('Roster',       prop.name + ' (id ' + prop.roster_id + ')') +
          field('Parent',       prop.parent_resource) +
          field('Incident',     prop.incident_name) +
          field('Release date', prop.proposed_release_date) +
          field('Status',       prop.current_status + ' → ' + prop.proposed_status) +
          (prop.reason ? field('Reason', prop.reason) : '') +
        '</dl>' +
        '<div class="admin-chat-proposal-actions">' +
          '<button type="button" class="btn btn-success btn-xs" data-approve>Approve demob</button>' +
          '<button type="button" class="btn btn-default btn-xs" data-dismiss>Dismiss</button>' +
        '</div>' +
        '<div class="admin-chat-proposal-result"></div>';
      log.appendChild(card);

      var result = card.querySelector('.admin-chat-proposal-result');
      card.querySelector('[data-approve]').addEventListener('click', function () {
        submitApproval('demob', prop.token, card, result);
      });
      card.querySelector('[data-dismiss]').addEventListener('click', function () {
        card.remove();
      });
      scrollToBottom();
    }

    function submitApproval(kind, token, card, result) {
      result.className = 'admin-chat-proposal-result';
      result.textContent = 'Approving…';
      card.querySelectorAll('button').forEach(function (b) { b.disabled = true; });

      fetch(log.dataset.approvalsUrl, {
        method: 'POST',
        credentials: 'same-origin',
        headers: {
          'Content-Type': 'application/json',
          'Accept':       'application/json',
          'X-CSRF-Token': csrfToken()
        },
        body: JSON.stringify({ kind: kind, token: token })
      })
      .then(function (r) { return r.json().then(function (b) { return { ok: r.ok, body: b }; }); })
      .then(function (res) {
        if (res.ok) {
          result.classList.add('ok');
          result.textContent = res.body.summary || 'Approved.';
        } else {
          result.classList.add('error');
          result.textContent = (res.body && res.body.error) || 'Approval failed.';
          card.querySelectorAll('button').forEach(function (b) { b.disabled = false; });
        }
      })
      .catch(function (err) {
        result.classList.add('error');
        result.textContent = 'Network error: ' + err.message;
        card.querySelectorAll('button').forEach(function (b) { b.disabled = false; });
      });
    }

    // Small italic banner that sits in-line with the chat log while
    // Claude is working (either waiting for the first text_delta or
    // between tool calls). Caller is responsible for .remove() once
    // the next event supersedes it.
    function appendToolBanner(text) {
      var el = document.createElement('div');
      el.className = 'admin-chat-thinking';
      el.textContent = text;
      log.appendChild(el);
      scrollToBottom();
      return el;
    }

    function scrollToBottom() { log.scrollTop = log.scrollHeight; }

    function field(label, value) {
      if (value == null || value === '') return '';
      var safe = String(value).replace(/[&<>"']/g, function (c) {
        return { '&':'&amp;', '<':'&lt;', '>':'&gt;', '"':'&quot;', "'":'&#39;' }[c];
      });
      return '<dt>' + label + ':</dt> <dd>' + safe + '</dd>';
    }

    function csrfToken() {
      var m = document.querySelector('meta[name="csrf-token"]');
      return m ? m.getAttribute('content') : '';
    }
  }

  // Rails UJS pages fire both DOMContentLoaded and turbolinks:load.
  document.addEventListener('DOMContentLoaded',   init);
  document.addEventListener('turbolinks:load',    init);
})();
