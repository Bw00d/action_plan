$(document).on("turbolinks:load", function() {

// Setting padding can be found in resize.js

// Select blocks
  $('.block').click(function() {
    $('.block').removeClass('block-selected');
    if (!($('.block')).hasClass('block-selected')) {
      $('.style-controls').hide();
      $('.new-block-type').hide();
      $('.new-block-form').hide();
      $('.edit_block').hide();
    }

    $(this).addClass('block-selected');
    if ($(this).hasClass('block-selected')) {
      $(this).siblings().toggle();
      $('.new-block-type').hide();
      var position = $(this).val('#new-block-position')
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

  //  temporary avatar
    function readURL(input) {

      if (input.files && input.files[0]) {
        var reader = new FileReader();

        reader.onload = function (e) {
          $('.cover-image').hide();
          $('#temp-image').show();
          $('#temp-image').attr('src', e.target.result);
        }

        reader.readAsDataURL(input.files[0]);
      }
    }

    $("#block_main_image").change(function(){
      readURL(this);
    });

  // New block type selection functionality
  var currentForm = null;
  
  // Show new block type selector when clicking the + button
  $(document).on('click', '.new-block-button', function(e) {
    e.preventDefault();
    currentForm = $(this).closest('form');
    $('.new-block-type').show();
  });
  
  // Cancel block type selection
  $('.cancel-block').click(function() {
    $('.new-block-type').hide();
    currentForm = null;
  });
  
  // Handle block type selection
  $('.block-type-option').click(function() {
    if (!currentForm) return;
    
    var $this = $(this);
    var form = currentForm;
    
    // Set default values
    form.find('#block_font_size').val('');
    form.find('#block_font_weight').val('normal');
    form.find('#block_text_style').val('');
    form.find('#block_text_align').val('left');
    form.find('#block_bottom_padding').val('25px');
    form.find('#block_image_block').val('false');
    form.find('#block_split_block').val('false');
    form.find('#block_content').val('Enter text here');
    
    // Handle split block selection
    if ($this.data('split-block')) {
      form.find('#block_split_block').val('true');
      form.find('#block_content').val('ADD AN IMAGE');
      form.find('#block_font_size').val('h2');
      form.find('#block_font_weight').val('bold');
      form.find('#block_text_align').val('center');
      form.find('#block_bottom_padding').val('50px');
      form.find('#block_image_block').val('true');
    } else if ($this.data('image-block')) {
      // Handle regular image block selection
      form.find('#block_content').val('ADD AN IMAGE');
      form.find('#block_font_size').val('h2');
      form.find('#block_font_weight').val('bold');
      form.find('#block_text_align').val('center');
      form.find('#block_bottom_padding').val('50px');
      form.find('#block_image_block').val('true');
    } else {
      // Handle text block selections
      if ($this.data('font-size')) {
        form.find('#block_font_size').val($this.data('font-size'));
      }
      if ($this.data('font-weight')) {
        form.find('#block_font_weight').val($this.data('font-weight'));
      }
      if ($this.data('text-style')) {
        form.find('#block_text_style').val($this.data('text-style'));
      }
    }
    
    // Hide the selector and submit the form
    $('.new-block-type').hide();
    form.submit();
    currentForm = null;
  });

});

