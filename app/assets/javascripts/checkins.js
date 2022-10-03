$(document).on("turbolinks:load", function() {
  $('select#checkin_category').change(function() {
    var text = $(this).val();
    $('#checkin-order-number-input').show();
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
});