$(document).on("turbolinks:load", function() {

  $('.datepicker').datepicker({
    assumeNearbyYear: true,
    autoclose: true,
    todayHighlight: true
  });

  // Auto-size best_in_place inputs to fit their content. Modern browsers
  // handle this via CSS `field-sizing: content`; this is the fallback that
  // sets the `size` attribute for browsers that don't yet support it.
  var supportsFieldSizing = window.CSS && CSS.supports && CSS.supports('field-sizing', 'content');
  if (!supportsFieldSizing) {
    $(document).on('focus', '.sm-bip-input input, .md-bip-input input, .lg-bip-input input', function () {
      var $input = $(this);
      function resize() {
        $input.attr('size', Math.max(($input.val() || '').length + 2, 4));
      }
      resize();
      $input.on('input.bipResize', resize);
      $input.one('blur.bipResize', function () { $input.off('.bipResize'); });
    });
  }
  
  $('select#resource_category').change(function() {
    var text = $(this).val();
    $('#order-number-input').show();
    switch(text) {
    case 'EQUIPMENT':  
      var prefix = 'E-'
     break;

    case 'CREW':  
      var prefix = 'C-'
      break;

    case 'OVERHEAD':
      var prefix = 'O-'
      break;

    case 'AIRCRAFT':
      var prefix = 'A-'
      break;
    }
      $('.order-number-prefix').html( prefix )

  });

 // Style glide rows
 //   demob day (LWD + 1) → black
 //   LWD                 → red
 //   LWD - 1, LWD - 2    → orange   (2 days before)
 //   LWD - 3..LWD - 5    → yellow   (3 days before that)
 //   anything earlier    → green
   $( ".glide-row" ).each( function( index, element ) {
      const day = Date.parse($(this).attr('data-day'))
      const lwd = Date.parse($(this).attr('data-lwd'))
      if (isNaN(lwd)) return;
      const ONE_DAY = 86400000;
      const demob_day = lwd + ONE_DAY;
      if (day === lwd) {
        $(this).addClass('red');
        $(this).text('LWD');
      } else if (day === demob_day) {
        $(this).addClass('black');
        $(this).text('DMB');
      } else if (day < lwd && day >= lwd - 2 * ONE_DAY) {
        $(this).addClass('orange');
      } else if (day < lwd - 2 * ONE_DAY && day >= lwd - 5 * ONE_DAY) {
        $(this).addClass('yellow');
      } else if (day < lwd - 5 * ONE_DAY) {
        $(this).addClass('green');
      }
  });


// tabrows

  $('a.resource-tab-link').click(function() {
    $('.resource-tab').removeClass('selected');
    $(this).parent().addClass('selected');
  })
  $('a#ics-211-tab').click(function (){
    $('#ics-211-info').show();
    $('#demob-info').hide();
    $('#glide-info').hide();
    $('#tally-info').hide();
  })
  $('a#glide-tab').click(function (){
    $('#ics-211-info').hide();
    $('#demob-info').hide();
    $('#glide-info').show();
    $('#tally-info').hide();
  })
  $('a#demob-tab').click(function (){
    $('#ics-211-info').hide();
    $('#glide-info').hide();
    $('#demob-info').show();
    $('#tally-info').hide();
  })
  $('a#tally-tab').click(function (){
    $('#ics-211-info').hide();
    $('#glide-info').hide();
    $('#demob-info').hide();
    $('#tally-info').show();
  })

// Reload page after creating resource
  // $('#submit-resource-button').click(function() {
  //   window.location.reload();
  // })

  // submitting forms

  $(".rnr-form-button").on("click", function (){
    $(this).parents('form:first').submit();
  });

    $(".fwd-datepicker").on("change", function (){
    $(this).parents('form:first').trigger('submit.rails');
    $('.datepicker-dropdown').hide();
  });


  $("tr.incident-resource").dblclick(function (){
    var id = $(this).attr('id').replace('resource-','');;
    var coord = ($(this).offset().top);
    $(".resource-comment").hide();
    $(`#comment-${id}`).css({ top: coord -100 }).show();

  });

  $("a.hide-comment").click(function (){
    $(".resource-comment").hide();
  });

  
});