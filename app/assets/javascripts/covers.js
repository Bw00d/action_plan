$(document).on("turbolinks:load", function() {


  $('.block').click(function() {
    $('.block').removeClass('block-selected');
    if (!($('.block')).hasClass('block-selected')) {
      $('.style-controls').hide();
      $('.new-block-form').hide();
    }

    $(this).addClass('block-selected');
    if ($(this).hasClass('block-selected')) {
      // $(this).prev('.style-controls').toggle();
      // $(this).closest('.new-block-form').toggle();
      $(this).siblings().toggle();
      }
  });
  $('.cover-block').hover(function() {
        $(this).find('.add-block-button').show();
      }, 
      function () {
        $(this).find('.add-block-button').hide();
      }
    );
  $('.add-block-button').hover(function() {
        $(this).show();
      }, 
      function () {
        $(this).hide();
      }
    );

  // style-controls
  $('.h1-text').click(function() {
    target = $(this).parent().siblings('.block')
    target.addClass('h1');
    target.removeClass('h2');
    target.removeClass('h3');
    target.removeClass('h4');
  });
  $('.h2-text').click(function() {
    target = $(this).parent().siblings('.block')
    target.addClass('h2');
    target.removeClass('h1');
    target.removeClass('h3');
    target.removeClass('h4');
  });
  $('.h3-text').click(function() {
    target = $(this).parent().siblings('.block')
    target.addClass('h3');
    target.removeClass('h1');
    target.removeClass('h2');
    target.removeClass('h4');
  });
  $('.h4-text').click(function() {
    target = $(this).parent().siblings('.block')
    target.addClass('h4');
    target.removeClass('h1');
    target.removeClass('h2');
    target.removeClass('h3');
  });
  $('.normal-text').click(function() {
    target = $(this).parent().siblings('.block')
    target.addClass('normal');
    target.removeClass('bold');
    target.removeClass('semi-bold');
  });
  $('.semi-text').click(function() {
    target = $(this).parent().siblings('.block')
    target.addClass('semi-bold');
    target.removeClass('normal');
    target.removeClass('bold');
  });
  $('.bold-text').click(function() {
    target = $(this).parent().siblings('.block')
    target.addClass('bold');
    target.removeClass('normal');
    target.removeClass('semi-bold');
  });
  $('.italic-text').click(function() {
    target = $(this).parent().siblings('.block')
    target.toggleClass('italic');
  });
  $('.add-image-block').click(function() {
    target = $(this).parent().siblings('.block');
    target.children('.image-form').toggle();
  });

});
