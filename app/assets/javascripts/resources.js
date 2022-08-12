$(document).on("turbolinks:load", function() {
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
    }
      $('.order-number-prefix').html( prefix )

  });

 // Style glide rows
   $( ".glide-row" ).each( function( index, element ) {
      const day = Date.parse($(this).attr('data-day'))
      const lwd = Date.parse($(this).attr('data-lwd'))
      const d_day =  Date.parse($(this).attr('data-lwd')) + 86400000
      const warning_day = Date.parse($(this).attr('data-lwd')) - 259200000
      if ($(this).attr('data-day') == $(this).attr('data-lwd')) {
          $(this).addClass('red');  
          $(this).text("LWD");  
      } else if ( day == d_day ) {
        $(this).addClass('black');
        $(this).text('DMB');
      } else if (day < lwd && day >= warning_day) {
        $(this).addClass('orange');
      } else if (day <  warning_day) {
        $(this).addClass('yellow');
      }
  });


// tabrows
  $('a#ics-211-tab').click(function (){
    $('#ics-211-info').show();
    $('#demob-info').hide();
    $('#glide-info').hide();
  })
  $('a#glide-tab').click(function (){
    $('#ics-211-info').hide();
    $('#demob-info').hide();
    $('#glide-info').show();
  })
  $('a#demob-tab').click(function (){
    $('#ics-211-info').hide();
    $('#glide-info').hide();
    $('#demob-info').show();
  })

  $('#submit-resource-button').click(function() {
    window.location.reload();
  })
  
});