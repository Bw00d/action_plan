// Feed interactions on the Incident Users page. Keeps behaviors delegated
// on document so they survive Turbolinks visits and future ActionCable
// re-renders drop-in cleanly (just replace the feed list — handlers stay).
$(document).on('turbolinks:load', function () {
  $(document).off('.feed');

  // Scroll the (capped-height) feed list to its bottom so the newest
  // posts are visible on land — matches the composer sitting below it.
  var $feed = $('.iup-card .feed-list');
  if ($feed.length) { $feed.scrollTop($feed[0].scrollHeight); }

  // Reply — reveal the inline composer under a top-level post.
  $(document).on('click.feed', '.feed-reply-btn', function () {
    var id = $(this).data('post-id');
    var $composer = $(this).closest('.feed-post').find('> .feed-reply-composer');
    $composer.show().find('textarea').focus();
  });

  $(document).on('click.feed', '.feed-cancel-reply', function () {
    $(this).closest('.feed-reply-composer').hide();
  });

  // Edit — swap the body for the edit form.
  $(document).on('click.feed', '.feed-edit-btn', function () {
    var id = $(this).data('post-id');
    var $post = $(this).closest('.feed-post');
    $post.find('> .feed-post-body').hide();
    $post.find('> .feed-edit-form').show().find('textarea').focus();
  });

  $(document).on('click.feed', '.feed-cancel-edit', function () {
    var $form = $(this).closest('.feed-edit-form');
    var $post = $form.closest('.feed-post');
    $form.hide();
    $post.find('> .feed-post-body').show();
  });
});
