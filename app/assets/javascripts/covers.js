$(document).on("turbolinks:load", function() {

// Setting padding can be found in resize.js

// Select blocks
  $('.block').click(function() {
    $('.block').removeClass('block-selected');
    if (!($('.block')).hasClass('block-selected')) {
      $('.style-controls').hide();
      $('.new-block-form').hide();
      $('.new-block-form').hide();
      $('.edit_block').hide();
    }

    $(this).addClass('block-selected');
    if ($(this).hasClass('block-selected')) {
      $(this).siblings().toggle();
      }
  });
// End

// Deselect blocks
  $(document).click(function() {
    var container = $('.block');
    if (!container.is(event.target) && !container.has(event.target).length) {
      $('.style-controls').hide();
      $('.new-block-form').hide();
      $('.block').removeClass('block-selected');
    }
  });
// End 

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
    target.children('.edit_block').show();
    $('input#block_font_size').val('h1');
  });
  $('.h2-text').click(function() {
    target = $(this).parent().siblings('.block')
    target.addClass('h2');
    target.removeClass('h1');
    target.removeClass('h3');
    target.removeClass('h4');
    target.children('.edit_block').show();
    $('input#block_font_size').val('h2');
  });
  $('.h3-text').click(function() {
    target = $(this).parent().siblings('.block')
    target.addClass('h3');
    target.removeClass('h1');
    target.removeClass('h2');
    target.removeClass('h4');
    target.children('.edit_block').show();
    $('input#block_font_size').val('h3');
  });
  $('.h4-text').click(function() {
    target = $(this).parent().siblings('.block')
    target.addClass('h4');
    target.removeClass('h1');
    target.removeClass('h2');
    target.removeClass('h3');
    target.children('.edit_block').show();
    $('input#block_font_size').val('h4');
  });
  $('.normal-text').click(function() {
    target = $(this).parent().siblings('.block')
    target.addClass('normal');
    target.removeClass('bold');
    target.removeClass('semi-bold');
    target.children('.edit_block').show();
    $('input#block_font_weight').val('normal');
  });
  $('.semi-text').click(function() {
    target = $(this).parent().siblings('.block')
    target.addClass('semi-bold');
    target.removeClass('normal');
    target.removeClass('bold');
    target.children('.edit_block').show();
    $('input#block_font_weight').val('semi-bold');
  });
  $('.bold-text').click(function() {
    target = $(this).parent().siblings('.block')
    target.addClass('bold');
    target.removeClass('normal');
    target.removeClass('semi-bold');
    target.children('.edit_block').show();
    $('input#block_font_weight').val('bold');
  });
  $('.italic-text').click(function() {
    target = $(this).parent().siblings('.block')
    target.children('.edit_block').show();
    
    if (target[0].classList.contains('italic')){
       $('input#block_text_style').val(' ');
      
    } else {
      $('input#block_text_style').val('italic');
    }
    target.toggleClass('italic');

  });
  $('.add-image-block').click(function() {
    target = $(this).parent().siblings('.block');
    target.children('.image-form').toggle();
  });

});

